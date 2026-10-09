const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();

/*
|--------------------------------------------------------------------------
| ADMIN RESET PASSWORD
|--------------------------------------------------------------------------
*/

exports.adminResetPassword = functions.https.onRequest(async (req, res) => {
  // CORS
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }

  try {
    const {email, newPassword} = req.body;

    if (!email || !newPassword) {
      return res.status(400).json({
        message: "Missing email or new password.",
      });
    }

    const user = await admin.auth().getUserByEmail(email);

    await admin.auth().updateUser(user.uid, {
      password: newPassword,
    });

    return res.status(200).json({
      message: "Password updated successfully!",
    });
  } catch (error) {
    console.error("Error resetting password:", error);

    return res.status(500).json({
      message: error.message || "Failed to reset password.",
    });
  }
});


/*
|--------------------------------------------------------------------------
| ORDER STATUS PUSH NOTIFICATION
|--------------------------------------------------------------------------
|
| Trigger:
| orders/{orderId}
|
| Kapag binago ng admin ang order status:
|
| Admin
|   ↓
| Firestore orders/{orderId}
|   ↓
| Cloud Function
|   ↓
| Notification history
|   ↓
| FCM push notification
|
|--------------------------------------------------------------------------
*/

exports.sendOrderStatusNotification = functions.firestore
    .document("orders/{orderId}")
    .onUpdate(async (change, context) => {
      try {
        const before = change.before.data() || {};
        const after = change.after.data() || {};

        const orderId = context.params.orderId;

        /*
        |--------------------------------------------------------------------------
        | GET OLD AND NEW STATUS
        |--------------------------------------------------------------------------
        */

        const oldStatus = String(
            before.orderStatus ||
            before.status ||
            "",
        ).trim();

        const newStatus = String(
            after.orderStatus ||
            after.status ||
            "",
        ).trim();

        /*
        |--------------------------------------------------------------------------
        | NO STATUS CHANGE = NO NOTIFICATION
        |--------------------------------------------------------------------------
        */

        if (oldStatus.toLowerCase() === newStatus.toLowerCase()) {
          console.log(
              `Order ${orderId}: status did not change.`,
          );

          return null;
        }

        /*
        |--------------------------------------------------------------------------
        | GET USER ID
        |--------------------------------------------------------------------------
        */

        const userId = String(
            after.userId ||
            before.userId ||
            "",
        ).trim();

        if (!userId) {
          console.log(
              `Order ${orderId}: no userId found.`,
          );

          return null;
        }

        /*
        |--------------------------------------------------------------------------
        | NOTIFICATION CONTENT
        |--------------------------------------------------------------------------
        */

        const title = "Order Update";

        const body =
            `Your order #${orderId} is now ${newStatus}.`;

        /*
        |--------------------------------------------------------------------------
        | CREATE NOTIFICATION HISTORY
        |--------------------------------------------------------------------------
        */

        const notificationRef = db
            .collection("users")
            .doc(userId)
            .collection("notifications")
            .doc();

        await notificationRef.set({
          title: title,
          body: body,
          type: "ORDER_UPDATE",
          status: newStatus,
          orderId: orderId,
          isRead: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        console.log(
            `Notification history created: ${notificationRef.id}`,
        );

        /*
        |--------------------------------------------------------------------------
        | GET USER FCM TOKENS
        |--------------------------------------------------------------------------
        */

        const userRef = db
            .collection("users")
            .doc(userId);

        const userSnapshot = await userRef.get();

        if (!userSnapshot.exists) {
          console.log(
              `User ${userId} does not exist.`,
          );

          return null;
        }

        const userData = userSnapshot.data() || {};

        let tokens = [];

        if (Array.isArray(userData.fcmTokens)) {
          tokens = userData.fcmTokens
              .filter(
                  (token) =>
                    typeof token === "string" &&
                    token.trim().length > 0,
              )
              .map((token) => token.trim());
        }

        /*
        |--------------------------------------------------------------------------
        | REMOVE DUPLICATE TOKENS
        |--------------------------------------------------------------------------
        */

        tokens = [...new Set(tokens)];

        if (tokens.length === 0) {
          console.log(
              `No FCM tokens found for user ${userId}.`,
          );

          return null;
        }

        console.log(
            `Sending order notification to ${tokens.length} device(s).`,
        );

        /*
        |--------------------------------------------------------------------------
        | FCM MESSAGE
        |--------------------------------------------------------------------------
        */

        const message = {
          tokens: tokens,

          notification: {
            title: title,
            body: body,
          },

          data: {
            type: "ORDER_UPDATE",
            orderId: orderId,
            userId: userId,
            status: newStatus,
            notificationId: notificationRef.id,
          },

          android: {
            priority: "high",

            notification: {
              channelId: "orders_channel",
              sound: "default",
            },
          },

          apns: {
            payload: {
              aps: {
                sound: "default",
              },
            },
          },
        };

        /*
        |--------------------------------------------------------------------------
        | SEND PUSH
        |--------------------------------------------------------------------------
        */

        const response =
            await admin.messaging().sendEachForMulticast(message);

        console.log(
            `FCM result for order ${orderId}:`,
            `${response.successCount} success,`,
            `${response.failureCount} failed`,
        );

        /*
        |--------------------------------------------------------------------------
        | REMOVE INVALID / EXPIRED TOKENS
        |--------------------------------------------------------------------------
        */

        const invalidTokens = [];

        response.responses.forEach((result, index) => {
          if (!result.success) {
            const errorCode = result.error?.code || "";

            console.error(
                `FCM failed for token ${index}:`,
                errorCode,
                result.error?.message || "",
            );

            if (
              errorCode ===
                  "messaging/invalid-registration-token" ||
              errorCode ===
                  "messaging/registration-token-not-registered"
            ) {
              invalidTokens.push(tokens[index]);
            }
          }
        });

        /*
        |--------------------------------------------------------------------------
        | CLEAN FIRESTORE TOKENS
        |--------------------------------------------------------------------------
        */

        if (invalidTokens.length > 0) {
          await userRef.update({
            fcmTokens:
                admin.firestore.FieldValue.arrayRemove(
                    ...invalidTokens,
                ),
          });

          console.log(
              `Removed ${invalidTokens.length} invalid FCM token(s).`,
          );
        }

        return null;
      } catch (error) {
        console.error(
            "Order status notification error:",
            error,
        );

        return null;
      }
    });