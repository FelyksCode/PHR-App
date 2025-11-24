# Mock FHIR Gateway Server for Testing

This directory contains a simple Node.js mock server for testing the PHR app during development.

## Setup

1. Install Node.js and npm
2. Run the following commands:

```bash
cd mock_server
npm init -y
npm install express cors body-parser
```

3. Create `server.js`:

```javascript
const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');

const app = express();
const port = 8080;

app.use(cors());
app.use(bodyParser.json());

// Mock storage
let observations = [];
let conditions = [];

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

// Submit observation
app.post('/api/health-data/observation', (req, res) => {
  console.log('Received observation:', JSON.stringify(req.body, null, 2));
  
  const observation = {
    ...req.body,
    id: req.body.id || generateId(),
    receivedAt: new Date().toISOString()
  };
  
  observations.push(observation);
  
  res.status(201).json({
    status: 'success',
    message: 'Observation created successfully',
    id: observation.id
  });
});

// Submit condition
app.post('/api/health-data/condition', (req, res) => {
  console.log('Received condition:', JSON.stringify(req.body, null, 2));
  
  const condition = {
    ...req.body,
    id: req.body.id || generateId(),
    receivedAt: new Date().toISOString()
  };
  
  conditions.push(condition);
  
  res.status(201).json({
    status: 'success',
    message: 'Condition created successfully',
    id: condition.id
  });
});

// Get all health data
app.get('/api/health-data', (req, res) => {
  res.json({
    observations: observations,
    conditions: conditions,
    counts: {
      observations: observations.length,
      conditions: conditions.length
    }
  });
});

// Get observations
app.get('/api/health-data/observations', (req, res) => {
  res.json({
    observations: observations,
    count: observations.length
  });
});

// Get conditions
app.get('/api/health-data/conditions', (req, res) => {
  res.json({
    conditions: conditions,
    count: conditions.length
  });
});

// Clear all data (for testing)
app.delete('/api/health-data', (req, res) => {
  observations = [];
  conditions = [];
  res.json({ status: 'success', message: 'All data cleared' });
});

function generateId() {
  return 'mock-' + Math.random().toString(36).substr(2, 9);
}

app.listen(port, () => {
  console.log(`Mock FHIR Gateway server listening at http://localhost:${port}`);
  console.log(`Health check: http://localhost:${port}/api/health`);
  console.log(`View data: http://localhost:${port}/api/health-data`);
});
```

4. Start the server:

```bash
node server.js
```

## Testing

The mock server will:
- Accept all observation and condition submissions
- Log received data to console
- Provide simple success responses
- Store data in memory for the session
- Provide endpoints to view submitted data

## Endpoints

- `GET /api/health` - Health check
- `POST /api/health-data/observation` - Submit observation
- `POST /api/health-data/condition` - Submit condition
- `GET /api/health-data` - View all submitted data
- `DELETE /api/health-data` - Clear all data

## Configuration

Update `lib/core/constants/api_constants.dart` to use the mock server:

```dart
static const String baseUrl = 'http://localhost:8080/api';
```