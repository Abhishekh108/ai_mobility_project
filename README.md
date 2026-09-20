# 🚗 AI Mobility Project

An intelligent urban mobility platform that provides **real-time AQI (Air Quality Index) forecasting**, **smart route recommendations**, and **route comparison** powered by machine learning and live data — built for Delhi NCR.

---

## ✨ Features

- 🌍 **Interactive Map View** — Google Maps integration with live traffic overlays
- 🏭 **AQI Forecast** — ML-based air quality predictions for Delhi stations
- 🛣️ **Smart Route Search** — Find optimal routes considering AQI & traffic
- 📊 **Route Comparison** — Side-by-side comparison of multiple routes
- 📈 **Real-time Data** — Live weather and AQI data integration

---

## 🧱 Tech Stack

### Frontend
| Tech | Purpose |
|------|---------|
| React + Vite | UI Framework |
| Google Maps API | Interactive mapping |
| Recharts / Chart.js | Data visualization |
| Vanilla CSS | Styling |

### Backend
| Tech | Purpose |
|------|---------|
| FastAPI | REST API framework |
| SQLite | Local database |
| Scikit-learn | ML models (AQI forecasting) |
| Uvicorn | ASGI server |

---

## 🚀 Getting Started

### Prerequisites
- Python 3.9+
- Node.js 18+
- Google Maps API Key

---

### 🔧 Backend Setup

```bash
cd backend

# Create virtual environment
python -m venv venv
source venv/bin/activate   # Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Configure environment variables
cp .env.example .env
# Edit .env and add your GOOGLE_MAPS_API_KEY

# Start the backend server
python -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
```

Backend API will be available at: `http://localhost:8000`  
API Docs (Swagger): `http://localhost:8000/docs`

---

### 🎨 Frontend Setup

```bash
cd frontend

# Install dependencies
npm install

# Configure environment variables
cp .env.example .env
# Edit .env and add your VITE_GOOGLE_MAPS_API_KEY

# Start the dev server
npm run dev
```

Frontend will be available at: `http://localhost:5173`

---

## 📁 Project Structure

```
ai_mobility_project/
├── backend/
│   ├── app/
│   │   ├── main.py          # FastAPI app entry point
│   │   ├── config.py        # Configuration settings
│   │   ├── database.py      # Database setup
│   │   ├── routes/          # API route handlers
│   │   └── services/        # Business logic & ML services
│   ├── ml/                  # ML model files
│   ├── requirements.txt
│   └── .env.example
├── frontend/
│   ├── src/
│   │   ├── components/      # React components
│   │   │   ├── AQIForecast.jsx
│   │   │   ├── MapView.jsx
│   │   │   ├── RouteSearch.jsx
│   │   │   └── RouteComparison.jsx
│   │   ├── services/
│   │   │   └── api.js       # API client
│   │   ├── App.jsx
│   │   └── index.css
│   ├── index.html
│   ├── package.json
│   └── .env.example
└── README.md
```

---

## 🔑 Environment Variables

### Backend (`backend/.env`)
```env
GOOGLE_MAPS_API_KEY=your_google_maps_api_key_here
DATABASE_URL=sqlite:///./aqi_system.db
```

### Frontend (`frontend/.env`)
```env
VITE_GOOGLE_MAPS_API_KEY=your_google_maps_api_key_here
VITE_API_BASE=http://localhost:8000
```

---

## 📡 API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/docs` | Swagger API documentation |
| GET | `/api/aqi/forecast` | AQI forecast data |
| GET | `/api/routes/search` | Route search |
| GET | `/api/routes/compare` | Route comparison |

---

## 👤 Author

**Abhishekh108**  
GitHub: [@Abhishekh108](https://github.com/Abhishekh108)

---

## 📄 License

This project is open-source and available under the [MIT License](LICENSE).
