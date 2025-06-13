"""
Logging Configuration for Mail-Rulez

Comprehensive logging setup with rotation, structured output, and containerization support.
Designed for production environments with configurable log levels and retention policies.
"""

import logging
import logging.handlers
import os
import sys
from pathlib import Path
from datetime import datetime
import json


class StructuredFormatter(logging.Formatter):
    """
    Custom formatter that outputs structured JSON logs for production environments
    while maintaining human-readable format for development.
    """
    
    def __init__(self, use_json=False):
        self.use_json = use_json
        if use_json:
            super().__init__()
        else:
            super().__init__(
                fmt='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
                datefmt='%Y-%m-%d %H:%M:%S'
            )
    
    def format(self, record):
        if not self.use_json:
            return super().format(record)
        
        # JSON structured logging for production
        log_entry = {
            'timestamp': datetime.fromtimestamp(record.created).isoformat(),
            'level': record.levelname,
            'logger': record.name,
            'message': record.getMessage(),
            'module': record.module,
            'function': record.funcName,
            'line': record.lineno
        }
        
        # Add extra fields if present
        if hasattr(record, 'account_email'):
            log_entry['account_email'] = record.account_email
        if hasattr(record, 'processing_mode'):
            log_entry['processing_mode'] = record.processing_mode
        if hasattr(record, 'email_count'):
            log_entry['email_count'] = record.email_count
        if hasattr(record, 'operation'):
            log_entry['operation'] = record.operation
        
        # Add exception info if present
        if record.exc_info:
            log_entry['exception'] = self.formatException(record.exc_info)
        
        return json.dumps(log_entry)


class LogConfig:
    """Configuration class for logging setup"""
    
    def __init__(self, 
                 log_dir: str = None,
                 log_level: str = None,
                 max_file_size: str = "10MB",
                 backup_count: int = 5,
                 use_json: bool = False,
                 enable_console: bool = True):
        
        # Environment-based defaults
        self.log_dir = log_dir or os.getenv('MAIL_RULEZ_LOG_DIR', 'logs')
        self.log_level = log_level or os.getenv('MAIL_RULEZ_LOG_LEVEL', 'INFO')
        self.max_file_size = max_file_size
        self.backup_count = backup_count
        self.use_json = use_json or os.getenv('MAIL_RULEZ_JSON_LOGS', 'false').lower() == 'true'
        self.enable_console = enable_console
        
        # Convert size string to bytes
        self.max_bytes = self._parse_size(max_file_size)
        
        # Ensure log directory exists
        Path(self.log_dir).mkdir(parents=True, exist_ok=True)
    
    def _parse_size(self, size_str: str) -> int:
        """Parse size string like '10MB' into bytes"""
        size_str = size_str.upper()
        if size_str.endswith('KB'):
            return int(size_str[:-2]) * 1024
        elif size_str.endswith('MB'):
            return int(size_str[:-2]) * 1024 * 1024
        elif size_str.endswith('GB'):
            return int(size_str[:-2]) * 1024 * 1024 * 1024
        else:
            return int(size_str)


def setup_logging(config: LogConfig = None) -> LogConfig:
    """
    Configure application-wide logging with rotation and structured output.
    
    Args:
        config: LogConfig instance, or None to use defaults
        
    Returns:
        LogConfig: The configuration used
    """
    if config is None:
        config = LogConfig()
    
    # Clear any existing handlers
    root_logger = logging.getLogger()
    for handler in root_logger.handlers[:]:
        root_logger.removeHandler(handler)
    
    # Set root log level
    root_logger.setLevel(getattr(logging, config.log_level.upper()))
    
    # Create formatter
    formatter = StructuredFormatter(use_json=config.use_json)
    
    # Console handler (for development and container logs)
    if config.enable_console:
        console_handler = logging.StreamHandler(sys.stdout)
        console_handler.setFormatter(formatter)
        console_handler.setLevel(getattr(logging, config.log_level.upper()))
        root_logger.addHandler(console_handler)
    
    # File handlers with rotation
    log_files = {
        'mail_rulez.log': logging.INFO,      # General application logs
        'email_processing.log': logging.INFO, # Email processing specific
        'security.log': logging.WARNING,     # Security events only
        'errors.log': logging.ERROR,         # Errors and above
        'debug.log': logging.DEBUG           # Debug logs (if enabled)
    }
    
    for log_file, file_level in log_files.items():
        # Skip debug logs unless explicitly enabled
        if file_level == logging.DEBUG and config.log_level.upper() != 'DEBUG':
            continue
        
        log_path = Path(config.log_dir) / log_file
        
        # Rotating file handler
        file_handler = logging.handlers.RotatingFileHandler(
            filename=log_path,
            maxBytes=config.max_bytes,
            backupCount=config.backup_count
        )
        file_handler.setFormatter(formatter)
        file_handler.setLevel(file_level)
        
        # Add custom filter for specific log files
        if log_file == 'email_processing.log':
            file_handler.addFilter(lambda record: 'email_processor' in record.name or 'task_manager' in record.name)
        elif log_file == 'security.log':
            file_handler.addFilter(lambda record: 'security' in record.name or 'auth' in record.name)
        
        root_logger.addHandler(file_handler)
    
    # Set specific logger levels for noisy libraries
    logging.getLogger('urllib3').setLevel(logging.WARNING)
    logging.getLogger('requests').setLevel(logging.WARNING)
    logging.getLogger('flask').setLevel(logging.INFO)
    logging.getLogger('apscheduler').setLevel(logging.INFO)
    
    return config


def get_logger(name: str, **extra_fields):
    """
    Get a logger with optional extra context fields.
    
    Args:
        name: Logger name
        **extra_fields: Additional fields to include in structured logs
        
    Returns:
        logging.Logger: Configured logger
    """
    logger = logging.getLogger(name)
    
    # Add extra fields as custom attributes
    for key, value in extra_fields.items():
        setattr(logger, key, value)
    
    return logger


class LogManager:
    """
    Utility class for managing log files, cleanup, and monitoring.
    """
    
    def __init__(self, log_dir: str = None):
        self.log_dir = Path(log_dir or os.getenv('MAIL_RULEZ_LOG_DIR', 'logs'))
    
    def get_log_files_info(self) -> dict:
        """Get information about all log files"""
        info = {}
        
        for log_file in self.log_dir.glob('*.log*'):
            stat = log_file.stat()
            info[log_file.name] = {
                'size_bytes': stat.st_size,
                'size_human': self._format_size(stat.st_size),
                'modified': datetime.fromtimestamp(stat.st_mtime).isoformat(),
                'lines': self._count_lines(log_file)
            }
        
        return info
    
    def cleanup_old_logs(self, days_to_keep: int = 30):
        """Remove log files older than specified days"""
        import time
        cutoff_time = time.time() - (days_to_keep * 24 * 60 * 60)
        
        removed_files = []
        for log_file in self.log_dir.glob('*.log.*'):  # Rotated logs only
            if log_file.stat().st_mtime < cutoff_time:
                log_file.unlink()
                removed_files.append(log_file.name)
        
        return removed_files
    
    def get_total_log_size(self) -> tuple:
        """Get total size of all log files"""
        total_bytes = sum(f.stat().st_size for f in self.log_dir.glob('*.log*'))
        return total_bytes, self._format_size(total_bytes)
    
    def _format_size(self, size_bytes: int) -> str:
        """Format size in human readable format"""
        for unit in ['B', 'KB', 'MB', 'GB']:
            if size_bytes < 1024:
                return f"{size_bytes:.1f}{unit}"
            size_bytes /= 1024
        return f"{size_bytes:.1f}TB"
    
    def _count_lines(self, file_path: Path) -> int:
        """Count lines in a file"""
        try:
            with open(file_path, 'r') as f:
                return sum(1 for _ in f)
        except Exception:
            return 0


# Environment-specific configurations
DEVELOPMENT_CONFIG = LogConfig(
    log_level='DEBUG',
    max_file_size='5MB',
    backup_count=3,
    use_json=False,
    enable_console=True
)

PRODUCTION_CONFIG = LogConfig(
    log_level='INFO',
    max_file_size='50MB',
    backup_count=10,
    use_json=True,
    enable_console=True  # For container logs
)

CONTAINER_CONFIG = LogConfig(
    log_level='INFO',
    max_file_size='20MB',
    backup_count=5,
    use_json=True,
    enable_console=True
)


def setup_for_environment(environment: str = None) -> LogConfig:
    """
    Setup logging for specific environment.
    
    Args:
        environment: 'development', 'production', 'container', or None for auto-detect
        
    Returns:
        LogConfig: The configuration used
    """
    if environment is None:
        # Auto-detect environment
        if os.getenv('FLASK_ENV') == 'development':
            environment = 'development'
        elif os.getenv('CONTAINER_ENV') == 'true':
            environment = 'container'
        else:
            environment = 'production'
    
    config_map = {
        'development': DEVELOPMENT_CONFIG,
        'production': PRODUCTION_CONFIG,
        'container': CONTAINER_CONFIG
    }
    
    config = config_map.get(environment, PRODUCTION_CONFIG)
    return setup_logging(config)


if __name__ == '__main__':
    # Example usage and testing
    config = setup_for_environment('development')
    
    logger = get_logger('test_logger', account_email='test@example.com')
    logger.info("Test log message", extra={'operation': 'testing'})
    logger.error("Test error message")
    
    # Test log manager
    manager = LogManager()
    print("Log files info:", manager.get_log_files_info())
    print("Total log size:", manager.get_total_log_size())