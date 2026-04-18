@echo off
REM Setup SonarQube for Flutter Project on Windows
REM This script helps set up SonarQube locally

echo 🔧 Setting up SonarQube for Flutter project...

REM Check if Docker is installed
docker --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Docker is required but not installed. Please install Docker Desktop first.
    echo 📥 Download from: https://www.docker.com/products/docker-desktop
    pause
    exit /b 1
)

REM Start SonarQube using Docker
echo 🐳 Starting SonarQube with Docker...
docker run -d --name sonarqube -p 9000:9000 sonarqube:latest

echo ⏳ Waiting for SonarQube to start...
timeout /t 30 /nobreak >nul

echo ✅ SonarQube is running at http://localhost:9000
echo 📝 Default credentials: admin/admin
echo 🔑 Don't forget to create a project and generate a token
echo 📖 Run 'sonar-scanner' to analyze your project
pause
