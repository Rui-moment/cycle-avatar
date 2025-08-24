# CycleAvatar Backend API

FastAPI-based backend for the CycleAvatar fitness tracking application.

## Features

- **FastAPI Framework**: Modern, fast web framework for building APIs
- **JWT Authentication**: Secure token-based authentication with refresh tokens
- **PostgreSQL Database**: Robust relational database with SQLAlchemy ORM
- **Database Migrations**: Alembic for database schema management
- **CORS Support**: Cross-origin resource sharing for mobile clients
- **OpenAPI Documentation**: Automatic API documentation generation

## Setup

### Prerequisites

- Python 3.8+
- PostgreSQL 12+
- pip or poetry for dependency management

### Installation

1. **Install dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

2. **Set up environment variables:**
   ```bash
   cp .env.example .env
   # Edit .env with your database credentials and JWT secret
   ```

3. **Create PostgreSQL database:**
   ```sql
   CREATE DATABASE cycleavatar;
   CREATE USER cycleavatar_user WITH PASSWORD 'your_password';
   GRANT ALL PRIVILEGES ON DATABASE cycleavatar TO cycleavatar_user;
   ```

4. **Initialize database:**
   ```bash
   # Create initial migration
   alembic revision --autogenerate -m "Initial migration"
   
   # Apply migrations
   alembic upgrade head
   
   # Or use the init script
   python app/db/init_db.py
   ```

### Running the Server

**Development mode:**
```bash
python main.py
```

**Production mode with Uvicorn:**
```bash
uvicorn main:app --host 0.0.0.0 --port 8000
```

The API will be available at:
- **API Base**: http://localhost:8000/api/v1
- **Documentation**: http://localhost:8000/docs
- **Health Check**: http://localhost:8000/health

### Testing

Run the basic API tests:
```bash
python test_api.py
```

## API Endpoints

### Authentication (`/api/v1/auth`)

- `POST /register` - Register new user
- `POST /login` - Login user (returns JWT tokens)
- `POST /refresh` - Refresh access token
- `POST /logout` - Logout user

### Users (`/api/v1/users`)

- `GET /me` - Get current user profile
- `PUT /me` - Update current user profile
- `DELETE /me` - Delete current user account

### Workouts (`/api/v1/workouts`)

- Placeholder endpoints (to be implemented in task 13.3)

## Database Schema

### Users Table
- `id` (UUID, Primary Key)
- `email` (String, Unique)
- `hashed_password` (String)
- `display_name` (String)
- `preferred_language` (String, default: 'en')
- `is_active` (Boolean, default: True)
- `created_at` (DateTime)
- `last_sync_at` (DateTime, nullable)

## Configuration

Key environment variables:

```env
# Database
DATABASE_URL=postgresql://user:password@localhost:5432/cycleavatar

# JWT
SECRET_KEY=your-secret-key-here
ACCESS_TOKEN_EXPIRE_MINUTES=15
REFRESH_TOKEN_EXPIRE_DAYS=30

# API
DEBUG=True
BACKEND_CORS_ORIGINS=["http://localhost:3000"]
```

## Security Features

- **Password Hashing**: bcrypt for secure password storage
- **JWT Tokens**: Short-lived access tokens (15 min) with long-lived refresh tokens (30 days)
- **CORS Protection**: Configurable allowed origins
- **Input Validation**: Pydantic models for request/response validation

## Development

### Adding New Endpoints

1. Create endpoint in `app/api/api_v1/endpoints/`
2. Add Pydantic schemas in `app/schemas/`
3. Create database models in `app/models/`
4. Update router in `app/api/api_v1/api.py`

### Database Migrations

```bash
# Create new migration
alembic revision --autogenerate -m "Description of changes"

# Apply migrations
alembic upgrade head

# Rollback migration
alembic downgrade -1
```

## Next Steps

- Task 13.2: Implement user management features (password reset, etc.)
- Task 13.3: Implement workout data synchronization APIs
- Add comprehensive test suite
- Set up production deployment configuration