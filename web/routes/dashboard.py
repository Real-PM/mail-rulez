"""
Dashboard routes for Mail-Rulez web interface

Provides overview, statistics, and system status information.
"""

from flask import Blueprint, render_template, jsonify, current_app, redirect, url_for, request
from functools import wraps
import psutil
import os
import sys
from datetime import datetime, timedelta
from pathlib import Path


dashboard_bp = Blueprint('dashboard', __name__)


def login_required(f):
    """Decorator to require authentication for routes"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if not current_app.get_current_user():
            return redirect(url_for('auth.login', next=request.url))
        return f(*args, **kwargs)
    return decorated_function


@dashboard_bp.route('/')
@dashboard_bp.route('/overview')
@login_required
def overview():
    """Main dashboard overview page"""
    # Get system stats
    stats = get_system_stats()
    
    # Get processing stats
    processing_stats = get_processing_stats()
    
    # Get recent activity
    recent_activity = get_recent_activity()
    
    # Get account stats
    account_stats = get_account_stats()
    
    return render_template('dashboard/overview.html',
                         stats=stats,
                         processing_stats=processing_stats,
                         recent_activity=recent_activity,
                         account_count=account_stats.get('active_accounts', 0))


@dashboard_bp.route('/api/stats')
@login_required
def api_stats():
    """API endpoint for real-time dashboard data"""
    return jsonify({
        'system': get_system_stats(),
        'processing': get_processing_stats(),
        'lists': get_list_stats(),
        'accounts': get_account_stats()
    })


@dashboard_bp.route('/api/logs')
@login_required
def api_logs():
    """API endpoint for recent log entries"""
    logs = get_recent_logs()
    return jsonify({'logs': logs})


def get_system_stats():
    """Get system resource statistics"""
    try:
        return {
            'cpu_percent': psutil.cpu_percent(interval=1),
            'memory_percent': psutil.virtual_memory().percent,
            'disk_usage': psutil.disk_usage('/').percent,
            'uptime': get_uptime(),
            'python_version': f"{sys.version.split()[0]}",
            'processes': len(psutil.pids())
        }
    except Exception as e:
        current_app.logger.error(f"Error getting system stats: {e}")
        return {
            'cpu_percent': 0,
            'memory_percent': 0,
            'disk_usage': 0,
            'uptime': 'Unknown',
            'python_version': 'Unknown',
            'processes': 0
        }


def get_processing_stats():
    """Get email processing statistics"""
    try:
        # Import here to avoid circular imports
        from services.task_manager import get_task_manager
        
        task_manager = get_task_manager()
        aggregate_stats = task_manager.get_aggregate_stats()
        
        # Get most recent last_run timestamp from all accounts
        from datetime import datetime
        most_recent_run = None
        all_status = task_manager.get_all_status()
        
        for account_email, account_status in all_status.get('accounts', {}).items():
            last_run_str = account_status.get('stats', {}).get('last_run')
            if last_run_str:
                try:
                    last_run = datetime.fromisoformat(last_run_str)
                    if most_recent_run is None or last_run > most_recent_run:
                        most_recent_run = last_run
                except (ValueError, TypeError):
                    continue
        
        # Format last_run for display
        if most_recent_run:
            last_run_display = most_recent_run.strftime('%Y-%m-%d %H:%M:%S')
        elif aggregate_stats.get('running_accounts', 0) > 0:
            last_run_display = 'Active'
        else:
            last_run_display = 'Never'
        
        # Convert to dashboard format
        stats = {
            'total_processed_today': aggregate_stats.get('total_emails_processed', 0),
            'whitelisted_today': 0,  # TODO: Implement daily breakdown
            'blacklisted_today': 0,  # TODO: Implement daily breakdown
            'pending_count': aggregate_stats.get('total_emails_pending', 0),
            'last_run': last_run_display,
            'processing_errors': aggregate_stats.get('total_errors', 0),
            'avg_processing_time': f"{aggregate_stats.get('avg_processing_time', 0):.1f}s" if aggregate_stats.get('avg_processing_time', 0) > 0 else 'N/A'
        }
        
        return stats
        
    except Exception as e:
        current_app.logger.error(f"Error getting processing stats: {e}")
        # Fallback stats in case of error
        return {
            'total_processed_today': 0,
            'whitelisted_today': 0,
            'blacklisted_today': 0,
            'pending_count': 0,
            'last_run': 'Never',
            'processing_errors': 0,
            'avg_processing_time': 'N/A'
        }


def get_list_stats():
    """Get email list statistics"""
    try:
        config = current_app.mail_config
        stats = {}
        
        for list_name, list_path in config.list_files.items():
            try:
                if list_path.exists():
                    with open(list_path, 'r') as f:
                        lines = [line.strip() for line in f.readlines() if line.strip()]
                        stats[list_name] = len(lines)
                else:
                    stats[list_name] = 0
            except Exception:
                stats[list_name] = 0
        
        return stats
    except Exception as e:
        current_app.logger.error(f"Error getting list stats: {e}")
        return {}


def get_account_stats():
    """Get email account statistics"""
    try:
        # Import here to avoid circular imports
        from services.task_manager import get_task_manager
        
        task_manager = get_task_manager()
        aggregate_stats = task_manager.get_aggregate_stats()
        system_status = task_manager.get_all_status()
        
        total_accounts = aggregate_stats.get('total_accounts', 0)
        running_accounts = aggregate_stats.get('running_accounts', 0)
        
        # Count error accounts
        error_accounts = 0
        account_names = []
        for account_email, account_status in system_status.get('accounts', {}).items():
            account_names.append(account_email)
            if account_status.get('state') == 'error':
                error_accounts += 1
        
        return {
            'total_accounts': total_accounts,
            'active_accounts': running_accounts,
            'inactive_accounts': total_accounts - running_accounts - error_accounts,
            'error_accounts': error_accounts,
            'account_names': account_names
        }
    except Exception as e:
        current_app.logger.error(f"Error getting account stats: {e}")
        return {
            'total_accounts': 0,
            'active_accounts': 0,
            'inactive_accounts': 0,
            'error_accounts': 0,
            'account_names': []
        }


def get_recent_activity():
    """Get recent system activity"""
    try:
        # Import here to avoid circular imports
        from services.task_manager import get_task_manager
        
        task_manager = get_task_manager()
        task_history = task_manager.get_task_history(limit=10)
        
        activities = []
        for task in task_history:
            # Convert task history to activity format
            activity = {
                'message': get_activity_message(task),
                'timestamp': datetime.fromisoformat(task['timestamp']),
                'status': get_activity_status(task['type'])
            }
            activities.append(activity)
        
        return activities
        
    except Exception as e:
        current_app.logger.error(f"Error getting recent activity: {e}")
        return []


def get_activity_message(task):
    """Convert task history entry to human-readable message"""
    task_type = task['type']
    details = task.get('details', {})
    
    if task_type == 'account_added':
        return f"Added account {details.get('account', 'unknown')}"
    elif task_type == 'account_removed':
        return f"Removed account {details.get('account', 'unknown')}"
    elif task_type == 'service_started':
        account = details.get('account', 'unknown')
        mode = details.get('mode', 'unknown')
        return f"Started {mode} processing for {account}"
    elif task_type == 'service_stopped':
        return f"Stopped processing for {details.get('account', 'unknown')}"
    elif task_type == 'service_restarted':
        return f"Restarted processing for {details.get('account', 'unknown')}"
    elif task_type == 'mode_switched':
        account = details.get('account', 'unknown')
        new_mode = details.get('new_mode', 'unknown')
        return f"Switched {account} to {new_mode} mode"
    elif task_type == 'auto_transition':
        account = details.get('account', 'unknown')
        to_mode = details.get('to_mode', 'unknown')
        return f"Auto-transitioned {account} to {to_mode} mode"
    else:
        return f"Task: {task_type}"


def get_activity_status(task_type):
    """Get activity status based on task type"""
    if task_type in ['service_started', 'account_added', 'auto_transition', 'mode_switched']:
        return 'success'
    elif task_type in ['service_stopped', 'account_removed']:
        return 'info'
    elif task_type == 'service_restarted':
        return 'info'
    else:
        return 'info'


def get_recent_logs():
    """Get recent log entries"""
    # TODO: Implement actual log reading
    # Return empty list until real log reading is implemented
    return []


def get_uptime():
    """Get system uptime"""
    try:
        boot_time = psutil.boot_time()
        uptime_seconds = datetime.now().timestamp() - boot_time
        
        days = int(uptime_seconds // 86400)
        hours = int((uptime_seconds % 86400) // 3600)
        minutes = int((uptime_seconds % 3600) // 60)
        
        if days > 0:
            return f"{days}d {hours}h {minutes}m"
        elif hours > 0:
            return f"{hours}h {minutes}m"
        else:
            return f"{minutes}m"
    except Exception:
        return "Unknown"