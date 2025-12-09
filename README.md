# Nomu – Investment Learning & Simulation Application
Graduation Project – Group 5
King Saud University

## 1. Project Overview:
Nomu is an educational application designed to help beginners in Saudi Arabia learn the fundamentals of investment and stock market trading through an interactive, gamified experience.

The system combines:
- Educational videos
- Daily investment challenges
- Interactive flashcards
- Virtual stock market simulation
- AI-powered price prediction

Nomu addresses the lack of financial awareness among investors and provides a safe, risk-free training environment aligned with the goals of Saudi Vision 2030.

___________________________________________________________________

## 2. Key Features
### 1. Learning Module
Structured lesson content (videos, playlists, flashcards) powered by Firebase Firestore
Interactive flashcards with swiping mechanics
Daily question with coin rewards

### 2. Market Simulation
Virtual balance & simulated trading environment
Buy/Sell operations based on real historical Tadawul data
Portfolio tracking, balance updates, and trade history

### 3. AI-Based Stock Predictions
RNN (LSTM) model for stock price direction prediction
Jupyter notebooks included under Release-2/Nomu_Models

### 4. Gamification
Coins and reward system
Motivational notifications

### 5. User Experience
Beginner-friendly UI
Arabic-first design
Clean navigation through Home, Learning, Simulation, Predictions, Portfolio, and More pages

___________________________________________________________________

## 3. Repository Structure
GP-Nomu/
│
├── Release-1/                      # First full release (application prototype)
│
├── Release-2/                      # Final release with ML models
│   └── Nomu_Models/
│       ├── *.ipynb                 # Jupyter notebooks (RNN, RF, checkpoints)
│       ├── *.csv                   # Datasets, cleaned market data
│       ├── *.tflite                # Converted models for mobile use
│       └── out/                    # Generated predictions & files
│
├── Nomu_Application/               # Final application
│
├── README.md                       # Project documentation
├── AUTHORS.md                      # Contributors
├── .gitignore
└── .gitattributes


___________________________________________________________________

## 4. Technologies Used
- Frontend: 
    Flutter (Dart)
    Material Design
    Firebase SDK

- Backend & Database:
    Firebase Firestore
    Firebase Authentication

- Machine Learning:
    Python
    TensorFlow / Keras
    Scikit-learn
    JupyterLab
    Random Forest Classifier
    RNN (LSTM)

- Other Tools:
    GitHub
    Git Bash
    Google Colab / Jupyter Notebooks

  ___________________________________________________________________
  
## 5. AI Models Included (Release-2)

Inside Release-2/Nomu_Models:
- RNN (LSTM) model
- Random Forest model
- Prediction notebooks
- Cleaned datasets

___________________________________________________________________

## 6. Application Screens

Includes:
- Home Page
- Learning Page
- Daily Challenge
- Video Lessons
- Interactive Flashcards
- Simulation Interface
- Portfolio Page
- Predictions Page
- Profile
- Favorites
- Wallet
- Support

___________________________________________________________________

## 7. Installation & Run Instructions
Prerequisites:
- Flutter SDK installed
- Android Studio or VS Code
- Connected device or emulator

Steps to Run
git clone https://github.com/asmaib/GP-Nomu.git
cd GP-Nomu
flutter pub get
flutter run

___________________________________________________________________


## 8. Contributors
- Norah Aljedai
- Asma Alshilash
- Alhanouf Aldakel  Allah
- Doaa Aldobai
- Raghd Ahmed Hassan

Supervised by
- Dr. Qatrunnada Alsmail
- Dr. Yousra Saud Almathami
