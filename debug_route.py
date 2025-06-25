#!/usr/bin/env python3
"""
Quick debug route to check admin file status
"""

from flask import Blueprint, jsonify, current_app
import os
from pathlib import Path

debug_bp = Blueprint('debug_admin', __name__, url_prefix='/debug')

@debug_bp.route('/admin-status')
def admin_status():
    """Debug endpoint to check admin file status"""
    try:
        config = current_app.mail_config
        
        # Check all possible locations
        base_admin = config.base_dir / '.admin_user'
        config_admin = config.config_dir / '.admin_user'
        
        # Check the needs_initial_setup function
        from web.routes.auth import needs_initial_setup
        
        debug_info = {
            'base_dir': str(config.base_dir),
            'config_dir': str(config.config_dir),
            'base_admin_file': str(base_admin),
            'config_admin_file': str(config_admin),
            'base_admin_exists': base_admin.exists(),
            'config_admin_exists': config_admin.exists(),
            'needs_initial_setup': needs_initial_setup(),
            'env_vars': {
                'MAIL_RULEZ_APP_DIR': os.getenv('MAIL_RULEZ_APP_DIR'),
                'MAIL_RULEZ_CONFIG_DIR': os.getenv('MAIL_RULEZ_CONFIG_DIR'),
            }
        }
        
        return jsonify(debug_info)
        
    except Exception as e:
        return jsonify({'error': str(e)})