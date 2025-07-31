#!/usr/bin/env python3
"""
Flask Scaffolding App Runner

This script provides an easy way to run the Flask application
with different configurations and options.
"""

import os
import sys
from app import app, db

def create_tables():
    """Create database tables."""
    with app.app_context():
        db.create_all()
        print("✅ Database tables created successfully!")

def seed_database():
    """Seed the database with sample data."""
    from app import User, Post
    
    with app.app_context():
        # Check if data already exists
        if User.query.first():
            print("ℹ️  Database already contains data. Skipping seed.")
            return
        
        # Create sample users
        user1 = User(username='john_doe', email='john@example.com')
        user2 = User(username='jane_smith', email='jane@example.com')
        user3 = User(username='admin', email='admin@example.com')
        
        db.session.add_all([user1, user2, user3])
        db.session.commit()
        
        # Create sample posts
        posts = [
            Post(title='Welcome to Flask!', 
                 content='This is your first Flask application. It includes user management, posts, and a beautiful UI built with Bootstrap 5.',
                 user_id=user1.id),
            Post(title='Getting Started with Development', 
                 content='To customize this application, start by exploring the templates in the templates/ folder and the static assets in static/.',
                 user_id=user2.id),
            Post(title='Database and Models', 
                 content='This app uses SQLAlchemy for database operations. You can find the models defined in app.py and easily extend them.',
                 user_id=user3.id),
            Post(title='Modern UI Components', 
                 content='The interface uses Bootstrap 5 with custom CSS for a modern look. Check out the cards, buttons, and responsive design!',
                 user_id=user1.id),
            Post(title='API Integration', 
                 content='The app includes REST API endpoints. Try visiting /api/users to see the JSON response for users data.',
                 user_id=user2.id),
        ]
        
        db.session.add_all(posts)
        db.session.commit()
        
        print("✅ Database seeded with sample data!")
        print(f"   - Created {len([user1, user2, user3])} users")
        print(f"   - Created {len(posts)} posts")

def run_development():
    """Run the application in development mode."""
    print("🚀 Starting Flask development server...")
    print("   URL: http://localhost:5000")
    print("   Environment: Development")
    print("   Debug: Enabled")
    print("\n   Press Ctrl+C to stop the server")
    print("-" * 50)
    
    app.run(debug=True, host='0.0.0.0', port=5000)

def run_production():
    """Run the application in production mode."""
    print("🚀 Starting Flask production server...")
    print("   Environment: Production")
    print("   Debug: Disabled")
    print("\n   Note: For production, consider using a WSGI server like Gunicorn")
    print("-" * 50)
    
    app.run(debug=False, host='0.0.0.0', port=5000)

def show_help():
    """Show help information."""
    help_text = """
Flask Scaffolding App Runner

Usage: python run.py [command]

Commands:
  dev, development    Start development server (default)
  prod, production    Start production server
  init, init-db       Initialize database tables
  seed, seed-db       Seed database with sample data
  setup               Initialize database and seed with sample data
  help, -h, --help    Show this help message

Examples:
  python run.py                 # Start development server
  python run.py dev             # Start development server
  python run.py setup           # Setup database and seed data
  python run.py init            # Initialize database only
  python run.py seed            # Seed database only
  python run.py prod            # Start production server

Environment Variables:
  SECRET_KEY          Secret key for Flask (default: development key)
  DATABASE_URL        Database URL (default: sqlite:///app.db)
  FLASK_ENV           Flask environment (development/production)
  FLASK_DEBUG         Enable debug mode (1/0)

For more information, see README.md
"""
    print(help_text)

def main():
    """Main entry point."""
    # Get command from arguments
    command = sys.argv[1] if len(sys.argv) > 1 else 'dev'
    
    # Handle commands
    if command in ['help', '-h', '--help']:
        show_help()
    elif command in ['init', 'init-db']:
        create_tables()
    elif command in ['seed', 'seed-db']:
        seed_database()
    elif command == 'setup':
        create_tables()
        seed_database()
        print("\n🎉 Setup complete! You can now run the application.")
        print("   Run: python run.py dev")
    elif command in ['dev', 'development']:
        run_development()
    elif command in ['prod', 'production']:
        run_production()
    else:
        print(f"❌ Unknown command: {command}")
        print("   Run 'python run.py help' for available commands")
        sys.exit(1)

if __name__ == '__main__':
    main()