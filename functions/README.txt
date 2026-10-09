# ArrozSistema FCM Backend

This backend sends push notifications through Firebase Cloud Messaging.

## What it handles

1. Order status notification:
   `users/{userId}/notifications/{notificationId}`

2. Delivery delay notice:
   `app_settings/delivery_notice`

The Flutter app already saves FCM tokens under:
- `users/{uid}.fcmTokens`
- `users/{uid}/fcmTokens/{tokenId}`

## Important

Cloud Functions deployment requires Firebase Cloud Functions to be enabled for the Firebase project. FCM itself does not charge per notification, but Cloud Functions is a billed Google Cloud service with a no-cost quota and requires a billing-enabled project for deployment.

## Deploy

From the Firebase project root:

```bash
firebase login
firebase use YOUR_FIREBASE_PROJECT_ID
firebase init functions
```

If Firebase asks whether to use an existing functions directory, use the `functions` directory containing this `index.js`.

Then:

```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```

After deployment, change an order status in the Admin app.

The Admin page already creates an `ORDER_UPDATE` notification document for the target user, so the Cloud Function will automatically send the FCM push.

## Test

1. Install the app on a physical Android phone.
2. Log in as a user.
3. Allow notifications.
4. Fully close the app.
5. From Admin, change the user's order status.
6. The phone should receive the notification.

For delivery-delay notifications, save an enabled/changed notice from the Admin page. The backend broadcasts it to registered user devices.
