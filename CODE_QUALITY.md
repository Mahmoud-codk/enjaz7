# Code Quality Setup Guide for Enjaz3 Flutter App

This document provides comprehensive instructions for setting up and using code quality tools for the Enjaz3 Flutter application.

## 🚀 Quick Start

### Prerequisites
- Flutter SDK (3.29.0 or higher)
- Dart SDK
- Git
- Docker Desktop (for SonarQube)
- Node.js (for SonarScanner)

### Installation Steps

1. **Install Flutter Quality Tools**
   ```bash
   # Install lcov for coverage reports
   choco install lcov  # Windows
   # or
   brew install lcov   # macOS
   ```

2. **Install SonarScanner**
   ```bash
   # Download from https://docs.sonarqube.org/latest/analysis/scan/sonarscanner/
   # Add to PATH environment variable
   ```

## 📋 Available Commands

### Windows (Batch Files)
```cmd
# Run all quality checks
scripts\quality-check.bat

# Setup SonarQube
scripts\setup-sonar.bat
```

### Cross-platform (Make)
```bash
# Run all quality checks
make quality

# Setup SonarQube
make setup-sonar

# Run tests with coverage
make coverage
```

### Direct Flutter Commands
```bash
# Format code
flutter format lib test

# Analyze code
flutter analyze

# Run tests
flutter test

# Run tests with coverage
flutter test --coverage
```

## 🔧 Configuration Files

### Enhanced Analysis Options
- **File**: `analysis_options.yaml`
- **Purpose**: Strict linting rules for better code quality
- **Features**: 100+ lint rules, strict type checking, custom exclusions

### SonarQube Configuration
- **File**: `sonar-project.properties`
- **Purpose**: SonarScanner configuration for Flutter/Dart
- **Features**: Coverage reporting, source exclusions, quality gates

### Test Configuration
- **File**: `dart_test.yaml`
- **Purpose**: Test execution configuration
- **Features**: Coverage reporting, timeout settings, platform support

## 🐳 SonarQube Setup

### Local Development
1. **Start SonarQube**
   ```bash
   # Using Docker
   docker run -d --name sonarqube -p 9000:9000 sonarqube:latest
   ```

2. **Access Dashboard**
   - URL: http://localhost:9000
   - Default credentials: admin/admin

3. **Create Project**
   - Project key: `enjaz7`
   - Project name: `Enjaz7 Flutter App`

4. **Generate Token**
   - Go to Administration > Security > Users > Tokens
   - Create a token for analysis

### SonarScanner Configuration
```bash
# Run analysis
sonar-scanner \
  -Dsonar.projectKey=enjaz3 \
  -Dsonar.sources=lib \
  -Dsonar.host.url=http://localhost:9000 \
  -Dsonar.login=your_token_here
```

## 📊 Coverage Reports

### Generate Coverage
```bash
# Run tests with coverage
flutter test --coverage

# Generate HTML report (requires lcov)
genhtml coverage/lcov.info -o coverage/html
```

### View Reports
- **LCOV**: `coverage/lcov.info`
- **HTML**: `coverage/html/index.html`

## 🔄 CI/CD Integration

### GitHub Actions
- **File**: `.github/workflows/flutter-quality.yml`
- **Features**: Automated quality checks on PR/push
- **Includes**: Formatting, analysis, tests, coverage, SonarCloud

### Quality Gates
- Code coverage > 80%
- No critical issues
- All tests passing
- Code formatted correctly

## 🛠️ Troubleshooting

### Common Issues

1. **SonarScanner Not Found**
   ```bash
   # Add to PATH
   set PATH=%PATH%;C:\sonar-scanner\bin
   ```

2. **Coverage Not Generated**
   ```bash
   # Ensure lcov is installed
   choco install lcov
   ```

3. **Docker Permission Issues**
   ```bash
   # Run as administrator
   # Or add user to docker-users group
   ```

4. **Flutter Analyze Errors**
   ```bash
   # Update dependencies
   flutter pub upgrade
   flutter pub get
   ```

## 📈 Quality Metrics

### Key Metrics Tracked
- **Code Coverage**: Percentage of code covered by tests
- **Technical Debt**: Time to fix code quality issues
- **Code Smells**: Potential code quality issues
- **Security Hotspots**: Potential security vulnerabilities
- **Duplications**: Code duplication percentage

### Quality Profiles
- **Flutter**: Optimized for Flutter development
- **Dart**: General Dart language rules
- **Security**: Security-focused rules

## 🎯 Next Steps

1. **Run Initial Quality Check**
   ```bash
   scripts\quality-check.bat
   ```

2. **Setup SonarQube**
   ```bash
   scripts\setup-sonar.bat
   ```

3. **Configure IDE**
   - Install Flutter/Dart plugins
   - Configure analysis options
   - Set up test runners

4. **Review Reports**
   - Check coverage reports
   - Review SonarQube dashboard
   - Address any issues

## 📞 Support

For issues or questions:
- Check the troubleshooting section
- Review Flutter documentation
- Check SonarQube documentation
- Create GitHub issues for project-specific problems

## 🔄 Updates

This setup will be updated as new tools and best practices emerge. Check back regularly for improvements.

## 🧹 Ktlint Setup and Usage

This project uses [ktlint](https://github.com/pinterest/ktlint) for Kotlin code style checking and formatting.

### Running ktlint

You can run ktlint checks and formatting using Gradle tasks added to the Android app module:

- To check Kotlin code style:
```bash
./gradlew :app:ktlintCheck
```

- To automatically format Kotlin code:
```bash
./gradlew :app:ktlintFormat
```

- To clean the downloaded ktlint jar:
```bash
./gradlew :app:cleanKtlint
```

The ktlint jar will be automatically downloaded to the build directory when running these tasks for the first time.

Make sure you have internet connectivity for the initial download.

### Troubleshooting

If you encounter errors related to ktlint not found or path issues, ensure the Gradle tasks are correctly configured in `android/app/build.gradle.kts` and that the jar is downloaded successfully.

If needed, you can manually download the ktlint jar from the [ktlint releases page](https://github.com/pinterest/ktlint/releases) and place it in the expected location.
