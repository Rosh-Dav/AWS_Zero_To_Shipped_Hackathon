module.exports = {
  testEnvironment: 'node',
  roots: ['<rootDir>/lambda/triage-engine'],
  testMatch: ['**/*.test.js'],
  moduleNameMapper: {
    // Stub all @aws-sdk/* packages — unit tests don't need real AWS calls
    '^@aws-sdk/(.*)$': '<rootDir>/lambda/triage-engine/__mocks__/aws-sdk-stub.js',
  },
};

