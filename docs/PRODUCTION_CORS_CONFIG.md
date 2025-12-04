# Production Backend CORS Configuration for sure.lazyrhythm.com

## Your Current Error

```
Access to fetch at 'https://sure.lazyrhythm.com/sessions/new' from origin 'http://localhost:51266'
has been blocked by CORS policy: No 'Access-Control-Allow-Origin' header is present
```

**This means your backend at `https://sure.lazyrhythm.com` needs CORS configuration.**

## Solution: Configure CORS on Your Backend Server

### Step 1: Add rack-cors gem

SSH into your production server or edit your `Gemfile`:

```ruby
# Gemfile
gem 'rack-cors'
```

Then run:
```bash
bundle install
```

### Step 2: Configure CORS

Create or edit `config/initializers/cors.rb`:

```ruby
# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # Allow requests from localhost for development
    # This allows testing the web app locally while connecting to production backend
    origins 'localhost:*', '127.0.0.1:*', /^http:\/\/localhost:\d+$/

    # If you deploy the web app to a domain, add it here:
    # origins 'https://your-web-app-domain.com'

    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true,
      expose: ['Authorization']
  end
end
```

### For Production Web App Deployment

If you plan to deploy the web app to a specific domain (e.g., `https://app.lazyrhythm.com`), use this configuration:

```ruby
# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # Allow both localhost (for development) and your production domain
    origins 'localhost:*',
            '127.0.0.1:*',
            /^http:\/\/localhost:\d+$/,
            'https://app.lazyrhythm.com'  # Replace with your actual domain

    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true,
      expose: ['Authorization']
  end
end
```

### Step 3: Restart Your Server

After updating the CORS configuration, **restart your Rails server**:

```bash
# If using systemd
sudo systemctl restart your-app-name

# If using Passenger
passenger-config restart-app /path/to/your/app

# If using Puma with a PID file
kill -USR2 $(cat tmp/pids/server.pid)

# Or simply restart the server process
```

### Step 4: Verify CORS Headers

Test if CORS is working:

```bash
curl -H "Origin: http://localhost:51266" \
     -H "Access-Control-Request-Method: POST" \
     -H "Access-Control-Request-Headers: Content-Type" \
     -X OPTIONS \
     --verbose \
     https://sure.lazyrhythm.com/api/v1/auth/login
```

You should see these headers in the response:
```
Access-Control-Allow-Origin: http://localhost:51266
Access-Control-Allow-Methods: GET, POST, PUT, PATCH, DELETE, OPTIONS, HEAD
Access-Control-Allow-Headers: Content-Type, Authorization
Access-Control-Allow-Credentials: true
```

## Alternative: Quick Test with Permissive CORS (Development Only)

**⚠️ WARNING: Only use this temporarily for testing, NOT in production!**

```ruby
# config/initializers/cors.rb - TEMPORARY TESTING ONLY
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins '*'  # Allow ALL origins (insecure!)

    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head]
  end
end
```

After confirming it works, **replace this with the proper configuration above** that specifies exact origins.

## Security Best Practices

### ✅ DO:
- Specify exact origins (e.g., `'localhost:*'`, `'https://app.lazyrhythm.com'`)
- Use HTTPS in production
- List only the origins you trust
- Use `credentials: true` only if you need cookies/auth headers

### ❌ DON'T:
- Use `origins '*'` in production (allows any website to access your API)
- Allow both `origins '*'` and `credentials: true` together (not allowed by browsers)
- Forget to restart the server after configuration changes

## Common Issues

### Issue: Still getting CORS errors after configuration

**Checklist:**
1. ✅ Added `gem 'rack-cors'` to Gemfile
2. ✅ Ran `bundle install`
3. ✅ Created `config/initializers/cors.rb` with correct configuration
4. ✅ **Restarted the server** (most commonly forgotten step!)
5. ✅ Cleared browser cache (Ctrl+Shift+Delete)

### Issue: CORS works for some endpoints but not others

This means CORS is configured but the `resource` pattern doesn't match all endpoints.

**Solution:** Use `resource '*'` to match all endpoints, or specify API paths:
```ruby
resource '/api/*', ...
resource '/sessions/*', ...
```

### Issue: Getting 403 Forbidden

Check your Rails middleware order. CORS middleware must be FIRST:
```ruby
config.middleware.insert_before 0, Rack::Cors do
  # The '0' means insert at the very beginning
end
```

## Testing After Configuration

1. **Restart backend server**
2. **Clear browser cache** (Ctrl+Shift+Delete)
3. **Restart the Flutter web app**: `flutter run -d chrome`
4. **Try connecting again**

If you see the error disappear, CORS is working! 🎉

## Need Help?

If CORS is still not working after following these steps:

1. Check the browser console for the exact error
2. Check backend logs for any errors
3. Verify the CORS configuration file exists and is loaded
4. Make sure you restarted the server
5. Try the curl command above to verify CORS headers

## Quick Reference

### Minimal Production Config
```ruby
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins 'localhost:*', 'https://your-production-domain.com'
    resource '*', headers: :any, methods: [:get, :post, :put, :patch, :delete, :options, :head], credentials: true
  end
end
```

### Check if rack-cors is installed
```bash
bundle list | grep rack-cors
```

### Check if CORS initializer exists
```bash
ls -la config/initializers/cors.rb
```
