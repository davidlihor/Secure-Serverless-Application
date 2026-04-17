interface AWSConfig {
  apiEndpoint: string;
  cognitoUserPoolId: string;
  cognitoClientId: string;
  cloudFrontDomain: string;
  region: string;
}

export const getConfig = (): AWSConfig => {
  const windowConfig = (window as any).AWS_CONFIG;
  
  return {
    apiEndpoint: windowConfig?.apiEndpoint || import.meta.env.VITE_API_ENDPOINT || '',
    cognitoUserPoolId: windowConfig?.cognitoUserPoolId || import.meta.env.VITE_COGNITO_USER_POOL_ID || '',
    cognitoClientId: windowConfig?.cognitoClientId || import.meta.env.VITE_COGNITO_CLIENT_ID || '',
    cloudFrontDomain: windowConfig?.cloudFrontDomain || import.meta.env.VITE_CLOUDFRONT_DOMAIN || '',
    region: windowConfig?.region || import.meta.env.VITE_AWS_REGION || 'us-east-1',
  };
};

export const config = getConfig();
