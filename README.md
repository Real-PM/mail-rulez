# Mail-Rulez

[![Python 3.9+](https://img.shields.io/badge/python-3.9+-blue.svg)](https://www.python.org/downloads/)
[![Flask](https://img.shields.io/badge/flask-3.1.0-green.svg)](https://flask.palletsprojects.com/)
[![Docker](https://img.shields.io/badge/docker-ready-blue.svg)](https://www.docker.com/)
[![License](https://img.shields.io/badge/license-AGPL--3.0-blue.svg)](LICENSE)

**Mail-Rulez** is an IMAP mailbox management system that automates email processing using rules-based filtering and list management. Originally a terminal application, it's now a containerized web app ready for multi-tenant SaaS deployment.

## 🚀 Quick Start

```bash
# Clone and deploy with Docker
git clone https://github.com/Real-PM/mail-rulez.git
cd mail-rulez/docker
./deploy-simple.sh
```
Access at `http://localhost:5001` - no configuration required!

## 🎯 Key Features

- **Smart Email Processing**: Rules-based filtering with whitelist/blacklist/vendor lists
- **Multi-Account Support**: Manage multiple IMAP accounts from one interface
- **Modern Web UI**: Responsive Bootstrap interface with visual rule builder
- **Enterprise Ready**: Docker containerization, health monitoring, and comprehensive logging
- **Secure by Design**: Encrypted storage, bcrypt passwords, CSRF protection
- **Well Tested**: 66+ tests with coverage reporting

## 📋 Installation

### Requirements
- Python 3.9+ or Docker 20.10+
- 512MB RAM (minimum)
- IMAP access to email servers

### Docker (Recommended)
```bash
# Simple deployment
cd mail-rulez/docker
./deploy-simple.sh

# Or manual deployment with custom config
python docker/scripts/generate_environment.py
docker-compose -f docker/docker-compose.yml up -d
```

### Local Development
```bash
# Set up environment
python -m venv ~/virtual-envs/mail-rulez
source ~/virtual-envs/mail-rulez/bin/activate
pip install -r requirements.txt

# Run application
cd web && python app.py
```

## ⚙️ Configuration

### Environment Setup
Copy `env-template` to `.env` and configure:

```bash
FLASK_PORT=5001
FLASK_SECRET_KEY=your-secret-key-here
MASTER_KEY=your-master-key-for-encryption
LOG_LEVEL=INFO
```

### Email Accounts
Configure through web interface: **Accounts** → **Add Account**

### Processing Rules
Create rules via: **Rules** → **Add Rule**

## 🛠️ Usage

### Web Interface
- **Dashboard**: Processing stats and system status
- **Accounts**: IMAP account management
- **Rules**: Email filtering rules
- **Lists**: Whitelist/blacklist management
- **Services**: Background task control

### Command Line
```bash
python process_inbox.py --account=myaccount  # Process emails
python admin_password_reset.py              # Reset password
pytest tests/                              # Run tests
```

### API
```bash
GET  /api/status    # System status
GET  /api/accounts  # List accounts
POST /api/process   # Trigger processing
```

## 🧪 Testing

```bash
# Run all tests with coverage
pytest --cov=. --cov-report=html

# Run in Docker
docker build -f docker/Dockerfile.test -t mail-rulez:test .
docker run --rm mail-rulez:test
```

## 🔒 Security

- **Encrypted configuration** storage
- **Bcrypt password** hashing
- **CSRF protection** on all forms
- **Input validation** throughout
- **Audit logging** for security events

### Password Recovery
Web: Navigate to `/auth/password-reset/request`  
CLI: Run `python admin_password_reset.py`

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes with tests
4. Push branch and open Pull Request

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

## 📄 License

GNU Affero General Public License v3.0 - see [LICENSE](LICENSE)

## 📚 Documentation

- [CLAUDE.md](CLAUDE.md) - Project instructions
- [DEPLOYMENT-NOTES.md](DEPLOYMENT-NOTES.md) - Deployment guide
- [DOCKER.md](DOCKER.md) - Container documentation

## 🚀 Roadmap

- Multi-tenant SaaS conversion
- Advanced ML-based filtering
- Mobile applications
- Cloud provider integration

---

**Mail-Rulez** - Intelligent Email Management Made Simple

For help, open an [issue](https://github.com/Real-PM/mail-rulez/issues) or check the [wiki](https://github.com/Real-PM/mail-rulez/wiki).
