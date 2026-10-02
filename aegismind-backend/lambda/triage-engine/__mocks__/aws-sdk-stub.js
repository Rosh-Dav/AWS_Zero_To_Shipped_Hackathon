// aws-sdk-stub.js — stubbed @aws-sdk/* for unit tests
const sendMock = jest.fn();
module.exports = {
  GetCommand: jest.fn(),
  ScanCommand: jest.fn(),
  UpdateCommand: jest.fn(),
  PutCommand: jest.fn(),
  DynamoDBClient: jest.fn(),
  DynamoDBDocumentClient: { from: jest.fn(() => ({ send: sendMock })) },
  __sendMock: sendMock,
};
