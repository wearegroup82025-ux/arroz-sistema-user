const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

exports.adminResetPassword = functions.https.onRequest(async (req, res) => {
  // Allow CORS
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }

  try {
    const {email, newPassword} = req.body;

    if (!email || !newPassword) {
      return res.status(400).json({message: "Missing email or new password."});
    }

    // Hanapin ang user sa Firebase Auth gamit ang email
    const user = await admin.auth().getUserByEmail(email);

    // I-update ang password sa Firebase Auth
    await admin.auth().updateUser(user.uid, {
      password: newPassword,
    });

    return res.status(200).json({message: "Password updated successfully!"});
  } catch (error) {
    console.error("Error resetting password:", error);
    return res.status(500).json({message: error.message || "Failed to reset password."});
  }
});

