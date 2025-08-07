from fastapi import FastAPI
from pydantic import BaseModel
from google.cloud import firestore  # type: ignore
from fcm_service import send_push_notification

app = FastAPI()
@app.get("/")
def read_root():
    return {"message": "Welcome to the backend API!"}

db = firestore.Client()  

# For general notifications
class NotificationRequest(BaseModel):
    token: str
    title: str
    body: str

@app.post("/send-notification/")
def notify(request: NotificationRequest):
    success = send_push_notification(request.token, request.title, request.body)
    return {"status": "sent" if success else "error"}


# New model for reviewing leave requests
class LeaveReviewRequest(BaseModel):
    leave_id: str
    status: str  # "approved" or "denied"

@app.post("/leave-review/")
def review_leave(request: LeaveReviewRequest):
    leave_ref = db.collection("leave_requests").document(request.leave_id)
    leave_doc = leave_ref.get()

    if not leave_doc.exists:
        return {"error": "Leave request not found"}

    leave_data = leave_doc.to_dict()
    user_id = leave_data.get("userId")

    # Update the status in Firestore
    leave_ref.update({"status": request.status})

    # Retrieve the user's FCM token
    user_doc = db.collection("users").document(user_id).get()
    if not user_doc.exists:
        return {"error": "User not found"}

    user_data = user_doc.to_dict()
    token = user_data.get("fcmToken")

    if token:
        title = "Leave Request Update"
        body = f"Your leave request has been {request.status}."
        send_push_notification(token, title, body)
        return {"status": f"Leave request {request.status} and notification sent"}
    else:
        return {"warning": "Leave status updated, but user has no FCM token"}
