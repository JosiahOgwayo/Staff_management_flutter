import os
from dotenv import load_dotenv
import firebase_admin
from firebase_admin import credentials, messaging

# Load environment variables from .env file
load_dotenv()

# Get credential file path from environment variable
cred_path = os.getenv("FIREBASE_CREDENTIALS_PATH")

# Initialize Firebase Admin SDK once (only if not already initialized)
if not firebase_admin._apps:
    if cred_path:
        cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(cred)
    else:
        raise ValueError("FIREBASE_CREDENTIALS_PATH not found in environment variables")

def send_push_notification(token: str, title: str, body: str):
    message = messaging.Message(
        notification=messaging.Notification(
            title=title,
            body=body,
        ),
        token=token,
    )

    try:
        response = messaging.send(message)
        print(f"Notification sent successfully: {response}")
        return True
    except Exception as e:
        print(f"Failed to send notification: {e}")
        return False
