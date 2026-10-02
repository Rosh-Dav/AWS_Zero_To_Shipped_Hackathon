const { handler } = require('./index');
const { __sendMock, GetCommand, ScanCommand } = require('@aws-sdk/lib-dynamodb');

describe('GET /sos/{incidentId}', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  const incident = {
    incidentId: 'd7c43ee3-1234-1234-1234-123456789012',
    status: 'OPEN',
    urgency: 'HIGH',
    category: 'FIRE',
  };

  it('finds an uppercase short ID after normalizing and scanning later pages', async () => {
    __sendMock
      .mockResolvedValueOnce({ Items: [], LastEvaluatedKey: { incidentId: 'previous-page' } })
      .mockResolvedValueOnce({ Items: [incident] });

    const response = await handler({
      httpMethod: 'GET',
      pathParameters: { incidentId: '  D7C43EE3  ' },
    });

    expect(response.statusCode).toBe(200);
    expect(ScanCommand.mock.calls[0][0].ExpressionAttributeValues[':ref']).toBe('d7c43ee3');
    expect(ScanCommand.mock.calls[1][0].ExclusiveStartKey).toEqual({ incidentId: 'previous-page' });
  });

  it('finds a lowercase short ID', async () => {
    __sendMock.mockResolvedValue({ Items: [incident] });

    const response = await handler({
      httpMethod: 'GET',
      pathParameters: { incidentId: 'd7c43ee3' },
    });

    expect(response.statusCode).toBe(200);
    expect(ScanCommand.mock.calls[0][0].ExpressionAttributeValues[':ref']).toBe('d7c43ee3');
  });

  it('uses GetItem for a full ID', async () => {
    __sendMock.mockResolvedValue({ Item: incident });

    const response = await handler({
      httpMethod: 'GET',
      pathParameters: { incidentId: incident.incidentId },
    });

    expect(response.statusCode).toBe(200);
    expect(GetCommand.mock.calls[0][0].Key).toEqual({ incidentId: incident.incidentId });
  });

  it('returns 404 only when an unknown ID has no matches', async () => {
    __sendMock.mockResolvedValue({ Items: [] });

    const response = await handler({
      httpMethod: 'GET',
      pathParameters: { incidentId: 'deadbeef' },
    });

    expect(response.statusCode).toBe(404);
  });

  it('should filter private fields for full UUID', async () => {
    __sendMock.mockResolvedValue({
      Item: {
        incidentId: '12345678-1234-1234-1234-123456789012',
        status: 'OPEN',
        urgency: 'HIGH',
        category: 'FIRE',
        assignedResources: ['FIRE_ENGINE'],
        updatedAt: '2023-01-01T00:00:00Z',
        reportCount: 2,
        etaMinutes: 10,
        rawMessage: 'Fire in the house!',
        translatedMessage: 'Fire in the house!',
        latitude: 10,
        longitude: 20,
        locationText: '123 Main St'
      }
    });

    const event = {
      httpMethod: 'GET',
      pathParameters: { incidentId: '12345678-1234-1234-1234-123456789012' }
    };
    
    const response = await handler(event);
    expect(response.statusCode).toBe(200);
    const body = JSON.parse(response.body);
    
    expect(body.referenceId).toBe('12345678');
    expect(body.status).toBe('OPEN');
    expect(body.urgency).toBe('HIGH');
    expect(body.category).toBe('FIRE');
    expect(body.etaMinutes).toBe(10);
    expect(body.assignedResources).toEqual(['FIRE_ENGINE']);
    
    // Check that private fields are NOT leaked
    expect(body.rawMessage).toBeUndefined();
    expect(body.translatedMessage).toBeUndefined();
    expect(body.latitude).toBeUndefined();
    expect(body.longitude).toBeUndefined();
    expect(body.locationText).toBeUndefined();
  });
  
  it('should filter private fields for short reference ID (Scan)', async () => {
    __sendMock.mockResolvedValue({
      Items: [{
        incidentId: '12345678-1234-1234-1234-123456789012',
        status: 'DISPATCHED',
        urgency: 'MEDIUM',
        category: 'MEDICAL',
        updatedAt: '2023-01-01T00:00:00Z',
        rawMessage: 'Need an ambulance',
        latitude: 10,
        longitude: 20
      }]
    });

    const event = {
      httpMethod: 'GET',
      pathParameters: { incidentId: '12345678' }
    };
    
    const response = await handler(event);
    expect(response.statusCode).toBe(200);
    const body = JSON.parse(response.body);
    
    expect(body.referenceId).toBe('12345678');
    expect(body.status).toBe('DISPATCHED');
    expect(body.rawMessage).toBeUndefined();
    expect(body.latitude).toBeUndefined();
  });
});

describe('GET /sos', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('returns incidents from every DynamoDB scan page', async () => {
    __sendMock
      .mockResolvedValueOnce({
        Items: [{ incidentId: 'older', timestamp: '2026-01-01T00:00:00.000Z' }],
        LastEvaluatedKey: { incidentId: 'older' },
      })
      .mockResolvedValueOnce({
        Items: [{ incidentId: 'newer', timestamp: '2026-01-02T00:00:00.000Z' }],
      });

    const response = await handler({ httpMethod: 'GET', pathParameters: null });

    expect(response.statusCode).toBe(200);
    expect(JSON.parse(response.body).map((item) => item.incidentId)).toEqual(['newer', 'older']);
    expect(ScanCommand.mock.calls[1][0].ExclusiveStartKey).toEqual({ incidentId: 'older' });
  });
});
