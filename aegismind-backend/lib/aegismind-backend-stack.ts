import 'dotenv/config';
import * as cdk from 'aws-cdk-lib/core';
import { Construct } from 'constructs';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import * as apigateway from 'aws-cdk-lib/aws-apigateway';
import * as path from 'path';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as s3deploy from 'aws-cdk-lib/aws-s3-deployment';
export class AegismindBackendStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    const incidentTable = new dynamodb.Table(this, 'IncidentsTable', {
      partitionKey: { name: 'incidentId', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    // GSI for querying incidents by status, sorted by timestamp.
    // Enables efficient filtered queries (e.g. all OPEN incidents, newest first).
    incidentTable.addGlobalSecondaryIndex({
      indexName: 'status-timestamp-index',
      partitionKey: { name: 'status', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'timestamp', type: dynamodb.AttributeType.STRING },
      projectionType: dynamodb.ProjectionType.ALL,
    });

    // Keys come from your shell env at `cdk deploy` time — never hardcoded
    // in source. See README for how to set them.
    const geminiApiKey = process.env.GEMINI_API_KEY;
    if (!geminiApiKey) {
      throw new Error(
        'GEMINI_API_KEY is not set in your environment. Set it before running `cdk deploy`.'
      );
    }
    const geminiModel = process.env.GEMINI_MODEL || 'gemini-2.0-flash';

    const triageEngine = new lambda.Function(this, 'TriageEngine', {
      runtime: lambda.Runtime.NODEJS_20_X,
      handler: 'index.handler',
      code: lambda.Code.fromAsset(path.join(__dirname, '..', 'lambda', 'triage-engine')),
      memorySize: 256,
      environment: {
        TABLE_NAME: incidentTable.tableName,
        GEMINI_API_KEY: geminiApiKey,
        GEMINI_MODEL: geminiModel,
        FORCE_UPDATE: new Date().toISOString(),
      },
      timeout: cdk.Duration.seconds(15),
    });

    incidentTable.grantReadWriteData(triageEngine);

    const api = new apigateway.RestApi(this, 'AegisMindAPI', {
      restApiName: 'AegisMind Service',
      defaultCorsPreflightOptions: {
        allowOrigins: apigateway.Cors.ALL_ORIGINS,
        allowMethods: apigateway.Cors.ALL_METHODS,
      },
      deployOptions: {
        throttlingRateLimit: 10,
        throttlingBurstLimit: 20,
      },
    });

    const sosResource = api.root.addResource('sos');
    const lambdaIntegration = new apigateway.LambdaIntegration(triageEngine);
    sosResource.addMethod('POST', lambdaIntegration);
    sosResource.addMethod('GET', lambdaIntegration);

    // GET and PATCH /sos/{incidentId}
    const incidentResource = sosResource.addResource('{incidentId}');
    incidentResource.addMethod('PATCH', lambdaIntegration);
    incidentResource.addMethod('GET', lambdaIntegration);

    // ────────────────────────────────────────────────────────────────
    // Phase C: Web App Deployment (S3 Static Hosting)
    // ────────────────────────────────────────────────────────────────

    const webBucket = new s3.Bucket(this, 'WebBucket', {
      websiteIndexDocument: 'index.html',
      websiteErrorDocument: 'index.html',
      publicReadAccess: true,
      blockPublicAccess: new s3.BlockPublicAccess({
        blockPublicAcls: false,
        blockPublicPolicy: false,
        ignorePublicAcls: false,
        restrictPublicBuckets: false,
      }),
      autoDeleteObjects: true,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    new s3deploy.BucketDeployment(this, 'DeployWeb', {
      sources: [s3deploy.Source.asset(path.join(__dirname, '..', '..', 'aegismind_frontend', 'build', 'web'))],
      destinationBucket: webBucket,
    });

    new cdk.CfnOutput(this, 'WebsiteURL', {
      value: webBucket.bucketWebsiteUrl,
    });
  }
}