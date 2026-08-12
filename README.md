# Crave

> A full-stack Flutter food ordering and table reservation platform connecting customers with local food businesses.

Crave is a portfolio-grade mobile application designed around a two-sided local food marketplace.

Customers can discover local shops, browse menus, order food for pickup or delivery, manage saved addresses, make payments, track orders, and book tables. Business owners have their own role-based experience for onboarding their shop, managing menus, receiving orders, and handling bookings.

The project is built with **Flutter + Supabase**, with PostgreSQL-backed data, authentication, realtime updates, location services, and a role-based application architecture.

---

## ✨ Overview

Crave brings two sides of a local food business together in one application:

### 👤 Customers

* Discover local shops
* View shop information and menus
* Browse menu items
* Add items to a cart
* Choose pickup or delivery
* Use a saved address or current location
* Place and track orders
* Manage saved addresses
* Manage payment methods
* Book tables at participating shops
* View account activity and profile information

### 🏪 Business Owners

* Create and onboard a shop
* Manage shop information
* Manage menu items
* Upload shop and menu images
* Receive incoming customer orders
* Update order status
* Manage customer bookings
* Access a dedicated owner dashboard

---

## 🛒 Customer Order Flow

```text
Discover Shop
      ↓
View Menu
      ↓
Select Items
      ↓
Add to Cart
      ↓
Choose Pickup / Delivery
      ↓
Select or Enter Address
      ↓
Checkout
      ↓
Payment
      ↓
Order Placed
      ↓
Order Tracking
      ↓
Order Completion
```

The application is designed around a real order lifecycle rather than a static shopping-cart demonstration.

---

## 🍽️ Table Booking Flow

Customers can also use Crave for restaurant/table reservations.

```text
Discover Shop
      ↓
View Shop
      ↓
Book a Table
      ↓
Select Booking Details
      ↓
Submit Reservation
      ↓
Booking Confirmation
```

Bookings are persisted through the Supabase backend and are part of the same business ecosystem as the ordering system.

---

## 🚀 Core Features

### Authentication & Authorization

* Email/password authentication
* Role-based signup
* Customer and owner accounts
* Role-based navigation
* Protected application routes
* Persistent authentication state
* Shop-aware owner routing

### Food Ordering

* Shop discovery
* Menu browsing
* Menu item details
* Local cart state
* Pickup fulfillment
* Delivery fulfillment
* Address selection
* Checkout flow
* Order creation
* Order cancellation where permitted
* Order status tracking

### Restaurant Management

* Shop onboarding
* Shop profile management
* Menu management
* Menu item creation
* Menu item image uploads
* Incoming order management
* Booking management
* Owner dashboard

### Location

* Device location access
* Current-location selection
* Geolocation
* Reverse geocoding
* Address management
* Google Maps integration

### Bookings

* Table reservation flow
* Booking persistence
* Owner-side booking management
* Backend RPC support for booking operations

### Realtime

Supabase Realtime is used for order-related state changes so that customer and owner experiences can react to backend updates without relying entirely on manual refreshes.

---

## 🏗️ Architecture

Crave follows a feature-oriented Flutter architecture.

```text
lib/
├── core/
│   ├── constants/
│   ├── routing/
│   ├── theme/
│   └── ...
│
├── features/
│   ├── auth/
│   ├── shops/
│   ├── cart/
│   ├── orders/
│   ├── payments/
│   ├── bookings/
│   ├── addresses/
│   ├── profile/
│   └── ...
│
├── app.dart
└── main.dart
```

The application separates shared infrastructure from domain-specific features, allowing individual areas such as authentication, ordering, bookings, and shop management to evolve independently.

---

## 🧰 Tech Stack

| Layer                 | Technology                      |
| --------------------- | ------------------------------- |
| Mobile framework      | Flutter                         |
| Language              | Dart                            |
| State management      | Riverpod                        |
| Navigation            | go_router                       |
| Backend               | Supabase                        |
| Database              | PostgreSQL                      |
| Authentication        | Supabase Auth                   |
| Realtime              | Supabase Realtime               |
| Maps                  | Google Maps Platform            |
| Location              | Geolocator                      |
| Geocoding             | Geocoding                       |
| Images                | Image Picker + Supabase Storage |
| Network image caching | Cached Network Image            |
| UI / Typography       | Material + Google Fonts         |

---

## 🔐 Backend

Crave uses Supabase as its backend platform.

The backend is responsible for:

* Authentication
* User profiles
* Customer/owner roles
* Shops
* Menus
* Orders
* Order items
* Bookings
* Saved addresses
* Payment-related data
* Database functions/RPCs
* Realtime database events
* Storage-backed images

This allows the Flutter application to communicate with a real backend instead of relying on hardcoded demo data.

---

## 📍 Location & Maps

Crave uses device location and Google Maps services to support the delivery experience.

The application includes:

* GPS-based current location
* Fine/coarse Android location permissions
* Reverse geocoding
* Address selection
* Google Maps integration

Google Maps API credentials should be configured locally and restricted to the intended Android application. **No API keys or credentials should be committed to this repository.**

---

## 💳 Payments

Crave includes a payment-oriented checkout architecture designed around test-mode payment processing.

The payment layer is separated from the customer-facing checkout flow so that payment processing can be integrated with an appropriate provider without coupling the rest of the ordering system directly to the provider implementation.

> Payment provider availability may vary by deployment region. Production payment configuration is intentionally environment-specific.

---

## ⚡ Realtime Order Tracking

Orders follow a defined lifecycle and the customer tracking experience can react to backend status changes.

Conceptually:

```text
Placed
  ↓
Confirmed
  ↓
Preparing
  ↓
Ready / Out for Delivery
  ↓
Completed
```

Cancellation is restricted according to the order's current state rather than allowing arbitrary cancellation after processing has begun.

---

## 🖼️ Images & Media

Crave supports image-based shop and menu management.

Business owners can upload:

* Shop/cover images
* Menu item images

Network images are cached on the client to improve the browsing experience and reduce unnecessary repeated downloads.

---

## 🔒 Security

This repository is intended to demonstrate application development while keeping credentials outside source control.

### Environment variables

Environment-specific configuration should be provided through a local `.env` file.

Example:

```env
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key
```

Never commit real credentials, private keys, service-role keys, or unrestricted third-party API credentials.

### Google Maps API

The Android Maps API key must be restricted using the appropriate Android application restrictions and API restrictions.

---

## 🛠️ Local Development

### Prerequisites

* Flutter SDK
* Dart SDK
* Android Studio / Android SDK
* A Supabase project
* Google Maps Platform configuration for Android

### 1. Clone the repository

```bash
git clone https://github.com/Abdul-Mueez-init/Portfolio_Delivery_App_Crave.git
cd Portfolio_Delivery_App_Crave
```

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Configure environment variables

Create a local `.env` file with the required Supabase configuration.

Do not commit this file.

### 4. Configure Google Maps

Create a Google Maps API key and restrict it to the intended Android package name and signing certificate.

Configure the key locally rather than committing an unrestricted credential to source control.

### 5. Run the application

```bash
flutter run
```

---

## 📁 Project Structure

```text
crave/
├── android/
├── ios/
├── lib/
│   ├── core/
│   ├── features/
│   ├── app.dart
│   └── main.dart
│
├── supabase/
│   └── database / RPC / backend SQL
│
├── assets/
│   └── images/
│
├── test/
├── pubspec.yaml
├── .gitignore
└── README.md
```

---

## 🎯 Project Goals

Crave was built as a portfolio project to demonstrate the development of a production-style, full-stack Flutter application with multiple user roles and real backend workflows.

The project focuses on demonstrating:

* Cross-platform Flutter development
* Feature-based application architecture
* State management
* Authentication
* Role-based authorization
* Backend integration
* PostgreSQL data modeling
* Realtime application behavior
* Location-aware workflows
* E-commerce/order flows
* Reservation workflows
* Payment architecture
* Media uploads
* Real-world application state management

---

## 📌 Project Status

Crave is an actively developed portfolio project.

The application is being developed incrementally, with features tested and refined throughout the development process.

Some integrations may remain environment-specific or require additional production configuration before commercial deployment.

---

## 🔮 Future Improvements

Potential future development includes:

* Production payment provider integration
* Push notifications
* Advanced restaurant discovery
* Search and filtering
* Ratings and reviews
* Improved delivery tracking
* Order history enhancements
* Promotional offers
* Restaurant analytics
* Production deployment and release automation

---

## 👨‍💻 Author

**Abdul Mueez**

Computer Science student and Flutter developer building full-stack mobile applications.

GitHub:
https://github.com/Abdul-Mueez-init

---

## 📄 License

This project is currently maintained as a personal portfolio project.
