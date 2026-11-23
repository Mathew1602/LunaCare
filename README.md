# LunaCare by Team LunaBear

LunaCare is a postpartum health monitoring platform designed to support early identification of postpartum depression risk and improve communication between mothers, caregivers, and healthcare providers.

The system combines an iOS and Apple Watch application, caregiver support features, a web-based Doctor Portal, Firebase services, and a machine-learning risk prediction service deployed on Google Cloud.

## Project Overview

LunaCare allows mothers to track their mood, symptoms, and health information while collecting additional physiological data from Apple Watch.

The collected data is stored in Firebase and used by the machine-learning service to generate a postpartum depression risk score. Authorized healthcare providers can review patient information through the Doctor Portal, verify ML-generated predictions, and manage clinical notes.

Authorized caregivers can also access selected health information shared by the mother.

## Main Features

### iOS Application

- Mood tracking
- Mood calendar and history
- Symptom tracking
- Symptom calendar and history
- Edit and delete mood records
- Daily symptom updates
- Health metrics from Apple Watch
- Personalized insights and recommendations
- Health alerts
- Doctor reports and clinical notes
- Caregiver invitation and authorization

### Apple Watch

- Collects supported health and activity measurements
- Sends health data to the iOS application
- Supports continuous health monitoring

Examples of collected data include:

- Heart rate
- Resting heart rate
- HRV
- Steps
- Active energy
- Sleep information
- Exercise activity

## Caregiver Support

Patients can authorize a caregiver to access selected health information.

Caregiver features include:

- Caregiver invitation
- Secure caregiver authorization
- View shared mood history
- View shared symptom history
- View health updates
- View support tips and recommendations

Patient consent remains part of the caregiver access workflow.

## Doctor Portal

The Doctor Portal is a React web application for authorized healthcare providers.

Doctors can:

- Sign in securely using Firebase Authentication
- View assigned patients
- Review patient health trends
- View mood and symptom history
- Review Apple Watch health data
- View ML-generated PPD risk scores
- Verify or unverify PPD predictions
- Create, edit, and delete clinical notes

Doctor access is controlled by the backend so healthcare providers can only access patients assigned to them.

## PPD Prediction Verification

The machine-learning service generates a PPD risk score using available patient health data.

The Doctor Portal allows a healthcare provider to review the prediction and mark it as clinically verified when it appears reasonable.

Verification information can include:

- Verification status
- Doctor ID
- Doctor name
- Verification timestamp
- Prediction score
- ML model version

If a new model version produces a new prediction, the new prediction requires another clinician review.

The ML score is intended as a decision-support feature and is not a clinical diagnosis.

## System Architecture

```text
iOS / Apple Watch
        |
        v
Firebase Authentication
        |
        v
Firebase Firestore
        |
        +----------------------+
        |                      |
        v                      v
Firebase Cloud Functions    ML Service
        |                      |
        |                 Google Cloud Run
        |                      |
        +----------<-----------+
        |
        v
Doctor Portal
React + Firebase Hosting
```

## Machine Learning Workflow

Patient health information is converted into the features required by the ML model.

The backend sends these records to the ML service deployed on Google Cloud Run.

The ML service:

1. Checks the currently published model metadata.
2. Loads the latest available model.
3. Processes the patient's health data.
4. Generates a PPD risk score.
5. Returns the score and model version to the backend.
6. Displays the result in the Doctor Portal.

Updated ML models can be published through the federated-learning workflow.

## Technology Stack

### Mobile

- Swift
- SwiftUI
- iOS
- watchOS
- HealthKit

### Doctor Portal

- React
- JavaScript
- Tailwind CSS
- Recharts

### Backend

- Firebase Cloud Functions
- Express
- Python Cloud Functions
- Firebase Admin SDK

### Database and Authentication

- Firebase Authentication
- Cloud Firestore
- Firebase Storage

### Cloud and Deployment

- Firebase Hosting
- Firebase Cloud Functions
- Google Cloud Run
- Google Cloud Storage
- Google Secret Manager

### Machine Learning

- Python
- XGBoost
- Federated learning workflow

## High-Level Data Flow

```text
Mother
  |
  v
LunaCare iOS App
  |
  +--> Mood & Symptom Tracking
  |
  +--> Apple Watch Health Data
  |
  v
Firebase
  |
  v
Backend
  |
  v
ML Prediction Service
  |
  v
PPD Risk Score
  |
  v
Doctor Portal
  |
  +--> Review Patient Data
  +--> Verify Prediction
  +--> Add Clinical Notes
  |
  v
Firebase
  |
  v
Patient iOS App
```

## Project Structure

```text
LunaCare/
├── iOS application
├── watchOS application
├── Doctor Portal
├── Firebase backend
├── Python Cloud Functions
└── Federated learning / ML services
```

## Running the iOS Application

Open the LunaCare project in Xcode.

Select the iOS application scheme and an iPhone simulator, then run the application.

For Apple Watch functionality, select the Watch App scheme and a compatible Apple Watch simulator.

Firebase configuration is provided through the project's Firebase configuration file.

## Running the Doctor Portal

Install dependencies:

```bash
npm install
```

Start the development server:

```bash
npm run dev
```

Create a production build:

```bash
npm run build
```

The production Doctor Portal is deployed using Firebase Hosting.

## Firebase Backend

The backend provides authenticated APIs for features such as:

- Doctor authentication
- Assigned patient access
- Patient detail retrieval
- PPD risk prediction
- Prediction verification
- Doctor notes
- Caregiver invitation and authorization

Firebase ID tokens are sent with protected requests and verified by the backend.

## Deployment

Firebase resources can be deployed using the Firebase CLI.

Example:

```bash
firebase deploy
```

Individual services can also be deployed separately:

```bash
firebase deploy --only hosting
```

```bash
firebase deploy --only functions
```

The ML prediction service is deployed separately to Google Cloud Run.

## Security

LunaCare uses:

- Firebase Authentication
- Backend authorization checks
- Doctor-to-patient assignment validation
- Firestore security rules
- Secure Cloud Function APIs
- Google Secret Manager for sensitive configuration

Sensitive credentials and service account files should never be committed to GitHub.

## Testing

Testing covers major application workflows, including:

- Mood tracking
- Symptom tracking
- Calendar history
- Apple Watch synchronization
- Caregiver access
- Doctor patient access
- PPD verification
- Clinical note management
- ML prediction workflow

## Capstone Project

LunaCare was developed as a Computer Systems Capstone Project at Sheridan College.

The project demonstrates the integration of:

- Mobile development
- Wearable health technology
- Cloud computing
- Machine learning
- Web development
- Secure backend APIs
- Healthcare-focused user experience

## Disclaimer

LunaCare is an academic prototype.

The ML-generated PPD risk score is intended for demonstration and decision-support purposes only. It has not been clinically validated and should not be used as a substitute for professional medical assessment, diagnosis, or treatment.
