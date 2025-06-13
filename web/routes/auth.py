"""
Authentication routes for Mail-Rulez web interface

Handles login, logout, and user session management using the integrated
security system.
"""

from flask import Blueprint, render_template, request, redirect, url_for, flash, session, current_app
from flask_wtf import FlaskForm
from wtforms import StringField, PasswordField, BooleanField, SubmitField
from wtforms.validators import DataRequired, Length
import os


auth_bp = Blueprint('auth', __name__)


class LoginForm(FlaskForm):
    """Login form with username and password"""
    username = StringField('Username', validators=[
        DataRequired(),
        Length(min=3, max=50, message='Username must be between 3 and 50 characters')
    ])
    password = PasswordField('Password', validators=[
        DataRequired(),
        Length(min=6, message='Password must be at least 6 characters')
    ])
    remember_me = BooleanField('Remember Me')
    submit = SubmitField('Sign In')


class SetupForm(FlaskForm):
    """Initial setup form for creating admin user"""
    username = StringField('Admin Username', validators=[
        DataRequired(),
        Length(min=3, max=50, message='Username must be between 3 and 50 characters')
    ])
    password = PasswordField('Admin Password', validators=[
        DataRequired(),
        Length(min=8, message='Password must be at least 8 characters')
    ])
    confirm_password = PasswordField('Confirm Password', validators=[
        DataRequired()
    ])
    submit = SubmitField('Create Admin Account')


@auth_bp.route('/login', methods=['GET', 'POST'])
def login():
    """Handle user login"""
    # Check if initial setup is needed
    if needs_initial_setup():
        return redirect(url_for('auth.setup'))
    
    form = LoginForm()
    
    if form.validate_on_submit():
        username = form.username.data
        password = form.password.data
        
        # Check if account is locked
        if current_app.security_manager.is_account_locked(username):
            flash('Account is temporarily locked due to too many failed login attempts. Please try again later.', 'error')
            return render_template('auth/login.html', form=form)
        
        # Verify credentials
        if verify_user_credentials(username, password):
            # Clear failed login attempts
            current_app.security_manager.clear_failed_attempts(username)
            
            # Create session
            session_token = current_app.session_manager.create_session(
                username,
                {'login_time': str(current_app.security_manager._failed_attempts)}
            )
            
            # Store session token in Flask session
            session['session_token'] = session_token
            session.permanent = form.remember_me.data
            
            flash(f'Welcome back, {username}!', 'success')
            
            # Redirect to originally requested page or dashboard
            next_page = request.args.get('next')
            if next_page:
                return redirect(next_page)
            return redirect(url_for('dashboard.overview'))
        else:
            # Record failed login attempt
            current_app.security_manager.record_failed_login(username)
            flash('Invalid username or password', 'error')
    
    return render_template('auth/login.html', form=form)


@auth_bp.route('/logout')
def logout():
    """Handle user logout"""
    session_token = session.get('session_token')
    if session_token:
        current_app.session_manager.destroy_session(session_token)
    
    session.clear()
    flash('You have been logged out successfully', 'info')
    return redirect(url_for('auth.login'))


@auth_bp.route('/setup', methods=['GET', 'POST'])
def setup():
    """Handle initial admin user setup"""
    if not needs_initial_setup():
        flash('Setup has already been completed', 'info')
        return redirect(url_for('auth.login'))
    
    form = SetupForm()
    
    if form.validate_on_submit():
        username = form.username.data
        password = form.password.data
        confirm_password = form.confirm_password.data
        
        # Validate password confirmation
        if password != confirm_password:
            flash('Passwords do not match', 'error')
            return render_template('auth/setup.html', form=form)
        
        # Create admin user
        if create_admin_user(username, password):
            flash('Admin account created successfully! Please log in.', 'success')
            return redirect(url_for('auth.login'))
        else:
            flash('Failed to create admin account. Please try again.', 'error')
    
    return render_template('auth/setup.html', form=form)


def needs_initial_setup():
    """Check if initial setup is needed"""
    # Check if admin user exists
    admin_file = current_app.mail_config.base_dir / '.admin_user'
    return not admin_file.exists()


def create_admin_user(username, password):
    """Create the initial admin user"""
    try:
        # Hash the password
        hashed_password = current_app.security_manager.hash_user_password(password)
        
        # Store admin credentials
        admin_file = current_app.mail_config.base_dir / '.admin_user'
        admin_data = f"{username}:{hashed_password}"
        
        admin_file.write_text(admin_data)
        
        # Set restrictive permissions
        admin_file.chmod(0o600)
        
        return True
    except Exception as e:
        current_app.logger.error(f"Failed to create admin user: {e}")
        return False


def verify_user_credentials(username, password):
    """Verify user login credentials"""
    try:
        admin_file = current_app.mail_config.base_dir / '.admin_user'
        
        if not admin_file.exists():
            return False
        
        admin_data = admin_file.read_text().strip()
        stored_username, stored_hash = admin_data.split(':', 1)
        
        # Check username and password
        if (current_app.security_manager.secure_compare(username, stored_username) and
            current_app.security_manager.verify_user_password(password, stored_hash)):
            return True
        
        return False
    except Exception as e:
        current_app.logger.error(f"Failed to verify credentials: {e}")
        return False


@auth_bp.route('/session/status')
def session_status():
    """API endpoint to check session status"""
    session_token = session.get('session_token')
    if session_token:
        user_session = current_app.session_manager.get_session(session_token)
        if user_session:
            return {
                'authenticated': True,
                'username': user_session['username'],
                'expires_in': 'TODO'  # Calculate remaining time
            }
    
    return {'authenticated': False}