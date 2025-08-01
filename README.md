# Employee Management App

A powerful employee management mobile application built with **Flutter**, **Firebase**, and **Python** (Firebase Admin SDK). This app enables admins to manage staff, assign tasks, authenticate users, and send push notifications — all from an intuitive mobile interface.

---

## Features

### Authentication

- Email and password login/signup
- Phone number authentication via OTP

### User & Profile Management

- Admins can add, view, and manage employee accounts
- Each staff member has a detailed profile page (editable and viewable)

### Clock-In System

- Staff can clock in daily with time tracking
- Admins can view attendance and prevent duplicate clock-ins

### Push Notifications *(In Progress)*

- Admins receive notifications when staff clock in
- Built using Firebase Cloud Messaging (manual push via Python & Flutter)

### Admin Dashboard

- Create and assign tasks
- View list of employees
- Manage user roles and permissions

---

## Tech Stack

| Layer        | Technology                         |
|------------- |------------------------------------|
| Frontend     | Flutter (Dart)                     |
| Backend      | Firebase (Firestore, Auth, FCM)    |
| Admin SDK    | Python (`firebase-admin`)          |
| Notifications| Firebase Cloud Messaging (FCM)     |
| State Mgmt   | Notifier-based                     |

---

## Getting Started

### Prerequisites

- Flutter SDK installed
- Firebase project set up
- Python 3.13.4 (for admin scripts / push notifications)
- VSCode (with Flutter plugins)
