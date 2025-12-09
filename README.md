Nomu – Investment Learning & Simulation Application

Graduation Project – Group 4
Princess Nourah bint Abdulrahman University

📘 Project Overview

Nomu is an educational mobile application designed to help beginners in Saudi Arabia learn the fundamentals of investment and stock market trading through an interactive, gamified experience.
The system combines:

Educational videos

Daily investment challenges

Interactive flashcards

Virtual stock market simulation

AI-powered price prediction (RNN + ML models)

Nomu addresses the lack of financial awareness among young investors and provides a safe, risk-free training environment aligned with the goals of Saudi Vision 2030.

🎯 Key Features
1. Learning Module

Structured lesson content (videos, playlists, flashcards) powered by Firebase Firestore

Interactive flashcards with swiping mechanics

Daily quiz question with coin rewards

2. Market Simulation

Virtual balance & simulated trading environment

Buy/Sell operations based on real historical Tadawul data

Portfolio tracking, balance updates, and trade history

3. AI-Based Stock Predictions

RNN (LSTM) model for stock price direction prediction

Random Forest model for investment signals

Jupyter notebooks included under Release-2/Nomu_Models

4. Gamification

Coins and reward system

Motivational notifications

Learning streak tracking (daily challenge)

5. User Experience

Beginner-friendly UI

Arabic-first design

Clean navigation through Home, Learning, Simulation, Predictions, and More pages

🗂️ Repository Structure
GP-Nomu/
│
├── Release-1/                  # First full release (application prototype)
│
├── Release-2/                  # Final release with ML models
│   └── Nomu_Models/
│       ├── *.ipynb             # Jupyter notebooks (RNN, RF, checkpoints)
│       ├── *.csv               # Datasets, cleaned market data
│       ├── *.tflite            # Converted models for mobile use
│       └── out/                # Generated predictions & files
│
├── README.md                    # Project documentation (this file)
├── AUTHORS.md                   # Contributors
├── .gitignore
└── .gitattributes

🛠️ Technologies Used
Frontend

Flutter (Dart)

Material Design

Firebase SDK

Backend & Database

Firebase Firestore

Firebase Authentication

Machine Learning

Python

TensorFlow / Keras

Scikit-learn

JupyterLab

Random Forest Classifier

RNN (LSTM)

Other Tools

GitHub

Git Bash

Google Colab / Jupyter Notebooks

🧠 AI Models Included (Release-2)

Inside Release-2/Nomu_Models:

✔ RNN (LSTM) model
✔ Random Forest model
✔ Data preprocessing scripts
✔ Converted .tflite versions
✔ Prediction notebooks
✔ Checkpoint versions
✔ Cleaned datasets

These models support:

Daily price direction classification

Buy/Sell signal generation

Historical data analysis

Model export for mobile prediction

📱 Application Screens

Includes:

Home Page

Learning Page

Daily Challenge

Video Lessons

Interactive Flashcards

Simulation Interface

Portfolio Page

Predictions Page

Profile, Favorites, Wallet, Support

(Screenshots included separately in the final GP2 submission.)

▶️ Video Demo

A full project video demonstration is included in the GP2 submission as:
Group4_Nomu_VideoDemo.mp4

📄 Documentation Included

Release-2 Report (PDF)

User Guide (PDF)

Admin Guide (if applicable)

System architecture diagrams

Class diagrams

UML Flowcharts

Testing & UAT results

👩‍💻 Installation & Run Instructions
Prerequisites

Flutter SDK installed

Android Studio or VS Code

Connected device or emulator

Firebase project setup

Steps to Run
git clone https://github.com/asmaib/GP-Nomu.git
cd GP-Nomu
flutter pub get
flutter run


Note: Firebase keys and configurations are not included for security reasons.

👥 Contributors

Listed separately in AUTHORS.md.

📜 License

This project is part of the Graduation Project course at Princess Nourah University.
Use of this code is restricted to educational and academic purposes.
