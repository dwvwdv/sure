# Web Platform CORS Configuration Guide

## Important: Flutter Web Compatibility

This app now includes **Web platform compatibility fixes**:

✅ **Secure Storage**: Web-compatible storage using SharedPreferences fallback
✅ **Error Handling**: Better error messages for connection issues
✅ **Timeout Configuration**: Proper timeout handling for all API requests
✅ **Platform Detection**: Automatic detection and handling of web platform

## Problem Overview

When running the Sure mobile app as a **web application**, you may encounter CORS (Cross-Origin Resource Sharing) errors when connecting to the backend API. This happens because:

- **Web browsers** enforce the Same-Origin Policy for security
- **Native apps (Android/iOS)** are NOT affected by CORS restrictions
- The **backend server** must explicitly allow cross-origin requests from web clients

## Symptoms

- Android/iOS apps connect successfully ✅
- Web app shows "connection failed" ❌
- Browser console shows CORS errors like:
  ```
  Access to fetch at 'http://localhost:3000/api/v1/auth/login' from origin 'http://localhost:8080'
  has been blocked by CORS policy: No 'Access-Control-Allow-Origin' header is present on the requested resource.
  ```

## Solution: Configure CORS on the Sure Backend

The Sure backend is built with Ruby on Rails. You need to configure the `rack-cors` gem to allow requests from your web app.

### Step 1: Install rack-cors gem

In your Sure backend repository, add to `Gemfile`:

```ruby
# Gemfile
gem 'rack-cors'
```

Then run:
```bash
bundle install
```

### Step 2: Configure CORS middleware

Create or update `config/initializers/cors.rb`:

```ruby
# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # For development - allow localhost on any port
    origins 'localhost:*', '127.0.0.1:*', /^http:\/\/localhost:\d+$/

    # For production - specify your actual domain
    # origins 'https://sure.your-domain.com'

    resource '/api/*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true,
      expose: ['Authorization']
  end

  # If you want to allow all origins (NOT recommended for production):
  # allow do
  #   origins '*'
  #   resource '*',
  #     headers: :any,
  #     methods: [:get, :post, :put, :patch, :delete, :options, :head]
  # end
end
```

### Step 3: Restart the backend server

```bash
# Stop the server (Ctrl+C if running)
# Then restart
rails server
```

### Step 4: Verify CORS headers

Test if CORS headers are present:

```bash
curl -H "Origin: http://localhost:8080" \
     -H "Access-Control-Request-Method: POST" \
     -H "Access-Control-Request-Headers: Content-Type" \
     -X OPTIONS \
     --verbose \
     http://localhost:3000/api/v1/auth/login
```

You should see these headers in the response:
- `Access-Control-Allow-Origin: http://localhost:8080`
- `Access-Control-Allow-Methods: GET, POST, PUT, PATCH, DELETE, OPTIONS, HEAD`
- `Access-Control-Allow-Headers: Content-Type, Authorization`

## Running the Web App

### Development Mode

```bash
# Run on default port (usually auto-assigned)
flutter run -d chrome

# Or specify a custom port
flutter run -d chrome --web-port=8080
```

### Build for Production

```bash
# Build web app
flutter build web

# The output will be in build/web/
# Deploy these files to your web server
```

## Configuration Tips

### Development Environment

For local development, use:
- **Backend URL**: `http://localhost:3000` (or your Rails server port)
- **Web App**: Runs on Flutter's dev server (usually `http://localhost:*`)

### Production Environment

1. **Update CORS origins** in `config/initializers/cors.rb`:
   ```ruby
   origins 'https://your-web-app-domain.com'
   ```

2. **Use HTTPS** for both frontend and backend in production

3. **Configure Backend URL** in the app:
   - Open the app
   - Go to "Backend Configuration" screen
   - Enter: `https://your-backend-domain.com`

## Security Considerations

### ⚠️ Important Security Notes

1. **Never use `origins '*'` in production** - this allows any website to make requests to your API

2. **Always specify exact origins** for production:
   ```ruby
   origins 'https://sure.your-domain.com', 'https://app.your-domain.com'
   ```

3. **Enable credentials only if needed**:
   - Set `credentials: true` if using cookies or HTTP authentication
   - This requires specific origins (cannot use wildcard)

4. **Limit exposed headers**:
   - Only expose headers that the frontend needs
   - Example: `expose: ['Authorization', 'X-Request-Id']`

5. **Use HTTPS in production**:
   - HTTP connections are not secure
   - Modern browsers may block mixed content (HTTPS → HTTP)

## Troubleshooting

### Issue: "Connection failed" without CORS error in console

This usually means:
1. **Backend URL is incorrect** - Check the URL in Backend Configuration screen
2. **Backend server is not running** - Ensure `rails server` is running
3. **Firewall blocking connection** - Check firewall settings
4. **Wrong port** - Ensure backend is running on the port you specified

**How to debug:**
1. Open browser DevTools (F12)
2. Go to Network tab
3. Try to login
4. Check if the request appears and what error it shows

### Issue: Still getting CORS errors after configuration

**Check:**
1. Backend server was restarted after CORS configuration
2. Origin in the error message matches the allowed origins
3. CORS middleware is loaded (check `config/application.rb`)
4. Check browser console for the exact error message

### Issue: Preflight OPTIONS requests failing

**Solution:**
- Ensure `options` is included in allowed methods
- Check that the CORS middleware is inserted BEFORE other middleware:
  ```ruby
  config.middleware.insert_before 0, Rack::Cors do
  ```

### Issue: Credentials (cookies) not being sent

**Solution:**
- Set `credentials: true` in CORS config
- In Flutter web, the `http` package should handle this automatically
- For fetch API: set `credentials: 'include'`

### Issue: Custom headers not allowed

**Solution:**
Add custom headers to allowed headers:
```ruby
resource '/api/*',
  headers: ['Content-Type', 'Authorization', 'X-Custom-Header'],
  # or use :any to allow all headers
  headers: :any
```

## Additional Resources

- [rack-cors GitHub](https://github.com/cyu/rack-cors)
- [MDN: CORS](https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS)
- [Rails CORS Configuration](https://guides.rubyonrails.org/configuring.html#configuring-middleware)
- [Flutter Web Deployment](https://docs.flutter.dev/deployment/web)

## Summary

To enable web app support and fix CORS issues:

1. ✅ Web platform files are now created in the `web/` directory
2. ✅ Configure CORS on the Sure backend (see Step 2 above)
3. ✅ Restart the backend server
4. ✅ Run the web app with `flutter run -d chrome`
5. ✅ Configure the backend URL in the app settings

The CORS configuration on the backend is **essential** - without it, web browsers will block all API requests for security reasons.
