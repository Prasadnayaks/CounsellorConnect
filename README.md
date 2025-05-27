# CounsellorConnect 🚀

CounsellorConnect is a comprehensive Flutter application designed to foster mental well-being by connecting users with professional counselors and providing a rich suite of self-care and journaling tools. It aims to be a supportive companion for users on their journey towards better mental health and self-understanding.

## ✨ Key Features

**For Users:**

* **Personalized Home Screen:** A dynamic dashboard with daily greetings, mood check-in prompts, and highlights like daily quotes, truth prompts, and challenges.
* **Mood Check-ins:** Track daily moods, associated activities, and feelings.
* **Journaling Suite:**
    * **Voice Notes:** Record and save audio reflections with speech-to-text capabilities.
    * **Daily Truth Prompts:** Engage with daily reflective questions and save responses with optional photos.
    * **General Entries:** A timeline view (`EntriesScreen`) to see all recorded activities.
    * **Photo Journaling:** Add general photos to complement journal entries.
* **Daily Challenges:** Participate in daily well-being challenges and track completion with photo uploads.
* **Inspirational Thoughts:** Browse a collection of quotes categorized for motivation and reflection.
* **Counselor Interaction:**
    * **Browse Counselors & Book Appointments:** View counselor profiles and schedule sessions.
    * **Live Chat:** Secure and confidential chat with booked counselors.
* **AI General Assistant:** An empathetic AI chatbot for general support and exploration of feelings, powered by Google's Gemini via a FastAPI backend.
* **Self-Care Tools:** Access guided exercises and resources.
* **Customizable Themes & Notifications:** Personalize the app's appearance and set reminders for check-ins and positivity.
* **Statistics:** View mood trends and insights.

* ![User_Demo](./assets/user.mp4)

**For Counselors:**

* **Dashboard:** Manage appointment requests (approve/decline), view upcoming and past sessions.
* **Availability Management:** Set and update weekly working hours.
* **User Chat:** Securely communicate with users who have booked sessions.
* **Private Journal:** A dedicated space for counselors' own notes and reflections.
* **Profile Management:** Update professional details, specialization, and description.

* ![Counsellor_Demo](./assets/counsellor.mp4)

## 🛠️ Tech Stack

* **Frontend:** Flutter (Dart)
* **Backend (Core):** Firebase (Authentication, Firestore, Storage)
* **Backend (AI Chatbot):** Python (FastAPI, Uvicorn) with Google Generative AI (Gemini) via WebSockets
* **State Management (Flutter):** Provider (primarily for theming, `setState` for local screen state)
* **Key Flutter Packages:** `firebase_auth`, `cloud_firestore`, `firebase_storage`, `image_picker`, `intl`, `speech_to_text`, `flutter_local_notifications`, `provider`, `lottie`, `cached_network_image`, `web_socket_channel`, `table_calendar`, `flutter_slidable`.

## 🚀 Getting Started

This project is a standard Flutter application.

**Prerequisites:**

* Flutter SDK (ensure `flutter doctor` reports no issues)
* For iOS: macOS with Xcode and CocoaPods
* For Android: Android Studio/SDK
* Firebase project setup (with `google-services.json` for Android and `GoogleService-Info.plist` for iOS configured in the respective platform folders).
* Python environment for the FastAPI backend.

**Running the Flutter App:**

1.  Clone the repository.
2.  Navigate to the project directory: `cd counsellorconnect`
3.  Install dependencies: `flutter pub get`
4.  Run the app: `flutter run`

**Running the FastAPI Chatbot Server (Python):**

1.  Navigate to the `careconnect_server` directory.
2.  Create a `.env` file in `careconnect_server/` with your `GEMINI_API_KEY`:
    ```env
    GEMINI_API_KEY="YOUR_GEMINI_API_KEY"
    ```
3.  Create and activate a virtual environment (recommended):
    ```bash
    python -m venv venv
    source venv/bin/activate  # On Windows: venv\Scripts\activate
    ```
4.  Install Python dependencies:
    ```bash
    pip install -r requirements.txt 
    ```
    *(You'll need to create a `requirements.txt` file in `careconnect_server/` based on your Python backend's dependencies: `fastapi`, `uvicorn[standard]`, `pydantic`, `pydantic-settings`, `python-dotenv`, `google-generativeai`, `websockets`)*
5.  Run the FastAPI server:
    ```bash
    uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
    ```
6.  **Important:** Update the `_webSocketUrl` in `lib/self_care/screens/general_chatbot_screen.dart` to point to your server's IP address if testing on a physical device or an emulator that isn't using `localhost` (e.g., `ws://YOUR_COMPUTER_LOCAL_IP:8000/ws/v1/careconnect_chat`).

## 📝 Future Enhancements (Examples)

* Video call integration for appointments.
* Group therapy session capabilities.
* Advanced analytics for users and counselors.
* More sophisticated AI chatbot features (e.g., RAG, tool use).

---

*This README was generated with the assistance of an AI coding partner.*
