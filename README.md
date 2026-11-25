# Supply Chain Management System (SCMS)

A complete web-based Supply Chain Management System built with React.js (Frontend) and Node.js/Express.js (Backend) with MySQL database.

## 📋 Project Overview

This system allows administrators to manage:
- **Suppliers** - Company information and contact details
- **Shipments** - Track shipments from suppliers
- **Deliveries** - Record and monitor delivery status
- **Reports** - Generate daily, weekly, and monthly reports

## 🏗️ Project Structure

```
scms/
├── database_script.sql      # MySQL database setup script
├── backend-project/         # Node.js/Express backend API
│   ├── .env                 # Environment configuration
│   ├── db.js                # Database connection module
│   ├── server.js            # Main Express server with API routes
│   └── package.json         # Backend dependencies
├── frontend-project/        # React.js/Vite frontend
│   ├── index.html           # HTML entry point
│   ├── package.json         # Frontend dependencies
│   ├── vite.config.js       # Vite configuration
│   ├── tailwind.config.js   # Tailwind CSS configuration
│   ├── postcss.config.js    # PostCSS configuration
│   └── src/
│       ├── main.jsx         # React entry point
│       ├── App.jsx          # Main application component
│       ├── index.css        # Global styles with Tailwind
│       ├── components/
│       │   └── Navbar.jsx   # Navigation sidebar
│       └── pages/
│           ├── Login.jsx    # Admin login page
│           ├── Dashboard.jsx# Main dashboard
│           ├── Supplier.jsx # Supplier management
│           ├── Shipment.jsx # Shipment management
│           ├── Delivery.jsx # Delivery management
│           └── Reports.jsx  # Reports page
└── README.md                # This file
```

## 🛠️ Technologies Used

### Frontend
- **React.js 18** - UI library
- **Vite** - Build tool and development server
- **React Router DOM 6** - Client-side routing
- **Axios** - HTTP client for API calls
- **Tailwind CSS 3** - Utility-first CSS framework

### Backend
- **Node.js** - JavaScript runtime
- **Express.js 4** - Web application framework
- **MySQL2** - MySQL database driver
- **CORS** - Cross-origin resource sharing
- **dotenv** - Environment variable management

### Database
- **MySQL** - Relational database management system

## 📊 Database Schema

### ERD (Entity Relationship Diagram)

```
┌─────────────┐       ┌─────────────┐       ┌─────────────┐
│   Supplier  │──────▶│  Shipment   │──────▶│  Delivery   │
│             │   1:M │             │   1:M │             │
├─────────────┤       ├─────────────┤       ├─────────────┤
│ supplierCode│       │shipmentNum. │       │ deliveryCode│
│ supplierName│       │ supplierCode│       │shipmentNum. │
│ telephone   │       │ shipmentDate│       │ deliveryDate│
│ address     │       │ shipmentStat│       │ quantity    │
│ email       │       │ destination │       │ deliveryStat│
└─────────────┘       └─────────────┘       └─────────────┘

┌─────────────┐
│    users    │  (Admin login)
├─────────────┤
│     id      │
│   username  │
│   password  │
└─────────────┘
```

### Relationships
- **One Supplier** can have **Many Shipments** (1:M)
- **One Shipment** can have **Many Deliveries** (1:M)

### Primary Keys
- `Supplier.supplierCode` - Auto Increment
- `Shipment.shipmentNumber` - Auto Increment
- `Delivery.deliveryCode` - Auto Increment
- `users.id` - Auto Increment

### Foreign Keys
- `Shipment.supplierCode` → `Supplier.supplierCode`
- `Delivery.shipmentNumber` → `Shipment.shipmentNumber`

## 🚀 Installation & Setup

### Prerequisites
- Node.js (v14 or higher)
- MySQL Server (v5.7 or higher)
- npm or yarn package manager

### Docker setup (MySQL + phpMyAdmin)

Docker Compose starts the application with a persistent MySQL database and a
local phpMyAdmin interface:

1. Copy `.env.docker.example` to `.env` and replace both database password
   placeholders with strong passwords.
2. Start the services from the project root:

```bash
docker compose up -d --build
```

3. Open `http://localhost:8081` (or the port set by `PHPMYADMIN_PORT`).
4. Sign in with the `DB_USER` and `DB_PASSWORD` values from `.env`. The
   database is `DB_NAME` (defaults to `SCMS`).

phpMyAdmin is bound to the local machine only. The MySQL data is stored in the
`scms_mysql_data` Docker volume and survives container restarts. The SQL setup
script runs only when that volume is first created.

### Step 1: Database Setup

1. Start your MySQL server
2. Run the database script:

```bash
# Method 1: Using MySQL command line
mysql -u root -p < database_script.sql

# Method 2: Using MySQL Workbench or phpMyAdmin
# Copy and paste the contents of database_script.sql
```

3. Verify the database was created:
```sql
SHOW DATABASES;
USE SCMS;
SHOW TABLES;
```

### Step 2: Backend Setup

```bash
# Navigate to backend directory
cd backend-project

# Install dependencies
npm install

# Configure environment (optional - defaults are set)
# Edit .env file with your MySQL credentials if needed

# Start the server
npm run dev
```

The backend server will start on `http://localhost:5000`

#### Integration Gateway

Supplier creation is saved together with an Integration Gateway outbox event.
The backend sends it to the documented `/api/v1/integration/events` endpoint
using the `supply-chain` source header and the same UUID for `event_id` and
`Idempotency-Key`. Configure the Gateway base URL and token in the backend
environment (never commit the token):

```text
INTEGRATION_GATEWAY_URL=http://localhost:8088/api/v1/integration
SUPPLY_CHAIN_INTEGRATION_TOKEN=<system-specific-token>
```

Copy `backend-project/.env.example` to `backend-project/.env`, then set the
token from your organization's approved secret store. Do not commit the `.env`
file.

The worker retries network errors and Gateway 5xx responses with the documented
1, 5, 15, 60, and 300 second delays; 4xx responses are not retried. For an
existing SCMS database, apply `database_migrations/002_create_integration_outbox.sql`
once before starting the backend. The supplier API response includes the event
and correlation IDs even while the event is pending delivery.

The current delivery form does not collect the part, unit, location, batch/heat,
supplier lot, and operator details required for a purchase receipt event, so
delivery records are not sent as inventory receipt events.

### Step 3: Frontend Setup

```bash
# Open a new terminal
# Navigate to frontend directory
cd frontend-project

# Install dependencies
npm install

# Start the development server
npm run dev
```

The frontend will start on `http://localhost:3000`

## 🔐 Default Login Credentials

- **Username:** `admin`
- **Password:** `admin123`

## 📡 API Endpoints

### Authentication
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/login` | Admin login |

### Suppliers
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/suppliers` | Get all suppliers |
| POST | `/suppliers` | Create new supplier |

### Shipments
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/shipments` | Get all shipments |
| POST | `/shipments` | Create new shipment |
| PUT | `/shipments/:id` | Update shipment |
| DELETE | `/shipments/:id` | Delete shipment |

### Deliveries
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/deliveries` | Get all deliveries |
| POST | `/deliveries` | Create new delivery |
| PUT | `/deliveries/:id` | Update delivery |
| DELETE | `/deliveries/:id` | Delete delivery |

### Reports
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/reports/daily` | Daily report |
| GET | `/reports/weekly` | Weekly report |
| GET | `/reports/monthly` | Monthly report |

## 🖥️ Usage Guide

### 1. Login
- Open `http://localhost:3000` in your browser
- Enter username: `admin` and password: `admin123`
- Click "Login" to access the dashboard

### 2. Manage Suppliers
- Click "Supplier" in the navigation menu
- Click "Add New Supplier" to create a supplier
- Fill in the form and click "Save Supplier"

### 3. Manage Shipments
- Click "Shipment" in the navigation menu
- Click "Add New Shipment" to create a shipment
- Select a supplier, enter date, status, and destination
- Use "Edit" and "Delete" buttons to modify shipments

### 4. Manage Deliveries
- Click "Delivery" in the navigation menu
- Click "Add New Delivery" to record a delivery
- Select a shipment and enter delivery details
- Use "Edit" and "Delete" buttons to modify deliveries

### 5. View Reports
- Click "Reports" in the navigation menu
- Select Daily, Weekly, or Monthly report
- View statistics and visual charts

## 🔧 Troubleshooting

### Database Connection Error
If you see "Database connection failed":
1. Ensure MySQL server is running
2. Check credentials in `backend-project/.env`
3. Verify the SCMS database exists

### CORS Error
If you see CORS errors:
1. Ensure backend server is running on port 5000
2. Check that both frontend and backend are running

### Port Already in Use
If port 3000 or 5000 is already in use:
1. Change the port in `frontend-project/vite.config.js` or `backend-project/server.js`
2. Or kill the process using that port

## 📝 Notes for Students

This project demonstrates:
1. **Full-stack development** - Frontend + Backend + Database
2. **RESTful API design** - Standard HTTP methods (GET, POST, PUT, DELETE)
3. **Database relationships** - One-to-many relationships with foreign keys
4. **Authentication** - Simple login system with session management
5. **CRUD operations** - Create, Read, Update, Delete functionality
6. **Responsive design** - Mobile-friendly UI with Tailwind CSS
7. **State management** - React hooks (useState, useEffect)
8. **API integration** - Axios for HTTP requests

## 📄 License

This project is created for educational purposes.

## 👨‍💻 Author

SCMS Development Team

---

**Good luck with your practical exam! 🎓**