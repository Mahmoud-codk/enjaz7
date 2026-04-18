@echo off
REM Flutter Quality Check Script for Windows
REM This script runs all quality checks for the Flutter project

echo 🔍 Starting Flutter Quality Checks...
echo.

REM Colors are not supported in standard Windows cmd
REM We'll use simple text indicators instead

REM Clean previous results
echo 🧹 Cleaning previous build artifacts...
flutter clean
if errorlevel 1 (
    echo ❌ Failed to clean project
    exit /b 1
)

flutter pub get
if errorlevel 1 (
    echo ❌ Failed to get dependencies
    exit /b 1
)

REM Format code
echo 🎨 Formatting code...
flutter format --set-exit-if-changed lib test
if errorlevel 1 (
    echo ❌ Code formatting issues found
    exit /b 1
)
echo ✅ Code formatted successfully

REM Analyze code
echo 🔍 Analyzing code...
flutter analyze --fatal-infos --fatal-warnings
if errorlevel 1 (
    echo ❌ Code analysis failed
    exit /b 1
)
echo ✅ Code analysis passed

REM Run tests with coverage
echo 🧪 Running tests with coverage...
flutter test --coverage
if errorlevel 1 (
    echo ❌ Some tests failed
    exit /b 1
)
echo ✅ All tests passed

REM Generate coverage report (requires lcov)
echo 📊 Generating coverage report...
if exist "coverage\lcov.info" (
    echo Generating HTML coverage report...
    REM Check if genhtml is available (requires lcov)
    where genhtml >nul 2>nul
    if %errorlevel%==0 (
        genhtml coverage\lcov.info -o coverage\html
        echo ✅ Coverage report generated at coverage\html\index.html
    ) else (
        echo ⚠️  genhtml not found. Install lcov to generate HTML coverage report
        echo ✅ Coverage data saved to coverage\lcov.info
    )
) else (
    echo ❌ No coverage data found
)

REM Check for outdated packages
echo 📦 Checking for outdated packages...
flutter pub outdated

echo.
echo ✅ All quality checks completed successfully!
pause
