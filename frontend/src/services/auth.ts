import {
  CognitoUserPool,
  CognitoUser,
  AuthenticationDetails,
  CognitoUserAttribute,
  CognitoUserSession,
} from 'amazon-cognito-identity-js';
import { config } from './config';

const poolData = {
  UserPoolId: config.cognitoUserPoolId,
  ClientId: config.cognitoClientId,
};

const userPool = new CognitoUserPool(poolData);

export class AuthService {

  static getCurrentUser(): CognitoUser | null {
    return userPool.getCurrentUser();
  }

  static getIdToken(): string | null {
    const user = this.getCurrentUser();
    if (!user) return null;
    
    let token: string | null = null;
    user.getSession((err: Error | null, session: CognitoUserSession) => {
      if (!err && session) {
        token = session.getIdToken().getJwtToken();
      }
    });
    return token;
  }

  static getCurrentUserEmail(): string {
    const user = this.getCurrentUser();
    return user?.getUsername() || '';
  }

  static getCurrentUserEmailAsync(): Promise<string> {
    return new Promise((resolve) => {
      const user = this.getCurrentUser();
      if (!user) {
        resolve('');
        return;
      }

      user.getSession((err: Error | null, session: CognitoUserSession) => {
        if (!err && session) {
          const payload = session.getIdToken().decodePayload();
          resolve(payload.email || user.getUsername() || '');
        } else {
          resolve(user.getUsername() || '');
        }
      });
    });
  }

  static getCurrentUserId(): string {
    const user = this.getCurrentUser();
    return user?.getUsername() || '';
  }

  static isAuthenticated(): boolean {
    return !!this.getCurrentUser();
  }

  static signUp(email: string, password: string): Promise<void> {
    return new Promise((resolve, reject) => {
      const attributeList = [
        new CognitoUserAttribute({ Name: 'email', Value: email }),
      ];

      userPool.signUp(email, password, attributeList, [], (err) => {
        if (err) {
          reject(new Error(err.message || 'Signup failed'));
          return;
        }
        resolve();
      });
    });
  }

  static confirmSignUp(email: string, code: string): Promise<void> {
    return new Promise((resolve, reject) => {
      const userData = {
        Username: email,
        Pool: userPool,
      };
      const cognitoUser = new CognitoUser(userData);

      cognitoUser.confirmRegistration(code, true, (err) => {
        if (err) {
          reject(new Error(err.message || 'Verification failed'));
          return;
        }
        resolve();
      });
    });
  }

  static signIn(email: string, password: string): Promise<void> {
    return new Promise((resolve, reject) => {
      const authenticationDetails = new AuthenticationDetails({
        Username: email,
        Password: password,
      });

      const userData = {
        Username: email,
        Pool: userPool,
      };
      const cognitoUser = new CognitoUser(userData);

      cognitoUser.authenticateUser(authenticationDetails, {
        onSuccess: () => {
          resolve();
        },
        onFailure: (err) => {
          reject(new Error(err.message || 'Login failed'));
        },
      });
    });
  }

  static signOut(): void {
    const user = this.getCurrentUser();
    if (user) {
      user.signOut();
    }
  }

  static resendVerificationCode(email: string): Promise<void> {
    return new Promise((resolve, reject) => {
      const userData = {
        Username: email,
        Pool: userPool,
      };
      const cognitoUser = new CognitoUser(userData);

      cognitoUser.resendConfirmationCode((err) => {
        if (err) {
          reject(new Error(err.message || 'Failed to resend code'));
          return;
        }
        resolve();
      });
    });
  }
}
