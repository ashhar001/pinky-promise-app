// src/components/AuthPage.js
import React, { useState, useRef, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import ReCAPTCHA from 'react-google-recaptcha';
import axiosInstance from '../api/axiosConfig';
import { useAuth } from '../hooks/useAuth';
import './AuthPage.css';

const AuthPage = () => {
    const [isLogin, setIsLogin] = useState(true);
    const [name, setName] = useState('');
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [error, setError] = useState('');
    const [loading, setLoading] = useState(false);
    const [captchaToken, setCaptchaToken] = useState('');
    const navigate = useNavigate();
    const recaptchaRef = useRef();
    const { isAuthenticated, checkAuthStatus } = useAuth();

    // Redirect if already authenticated
    useEffect(() => {
        if (isAuthenticated) {
            navigate('/chat');
        }
    }, [isAuthenticated, navigate]);

    const handleCaptchaChange = (token) => {
        setCaptchaToken(token);
    };

    const handleSubmit = async (e) => {
        e.preventDefault();
        setError('');
        setLoading(true);

        if (!captchaToken) {
            setError('Please complete the captcha verification');
            setLoading(false);
            return;
        }

        // Store the current mode to handle post-request logic
        const currentMode = isLogin;

        try {
            if (isLogin) {
                const response = await axiosInstance.post('/api/auth/login', {
                    email,
                    password,
                    captchaToken: captchaToken
                });

                if (response.data.accessToken) {
                    localStorage.setItem('accessToken', response.data.accessToken);
                    localStorage.setItem('refreshToken', response.data.refreshToken);
                    checkAuthStatus();
                    window.dispatchEvent(new CustomEvent('authStateChanged'));
                    navigate('/chat');
                }
            } else {
                const response = await axiosInstance.post('/api/auth/register', {
                    name,
                    email,
                    password,
                    captchaToken: captchaToken
                });
                
                // Keep the captcha token valid for login
                setError('Registration successful! You can now login with your credentials.');
                setName('');
                // Don't clear email to make login easier
                setPassword('');
                setIsLogin(true);
            }
        } catch (err) {
            console.error('Auth error:', err);
            
            if (err.message === 'Request timeout. Please try again.') {
                setError('Server is taking too long to respond. Please try again.');
            } else if (err.response?.data?.detail) {
                setError(err.response.data.detail);
            } else if (err.response?.data?.error) {
                // Handle specific captcha errors with clearer messages
                if (err.response.data.error === "Captcha verification failed") {
                    setError('Captcha verification failed. Please try again with a new captcha.');
                    
                    // Always reset captcha on verification failure
                    if (recaptchaRef.current) {
                        recaptchaRef.current.reset();
                        setCaptchaToken('');
                    }
                } else {
                    setError(err.response.data.error);
                }
            } else if (err.code === 'ERR_NETWORK') {
                setError('Cannot connect to server. Please check if the backend is running.');
            } else {
                setError(isLogin ? 'Login failed. Please try again.' : 'Registration failed. Please try again.');
            }

            // Only reset captcha on non-captcha errors if necessary
            // We've already handled captcha verification errors above
            if (!err.response?.data?.error?.includes("Captcha") && recaptchaRef.current) {
                recaptchaRef.current.reset();
                setCaptchaToken('');
            }
        } finally {
            setLoading(false);
        }
    };

    const toggleAuthMode = () => {
        setIsLogin(!isLogin);
        setError('');
        
        // Only clear fields that need to be cleared
        if (!isLogin) { // Switching from signup to login
            setName('');
            // Keep email for convenience
        } else { // Switching from login to signup
            // Clear all fields for new registration
            setName('');
            setEmail('');
        }
        
        // Always clear password for security
        setPassword('');
        
        // Don't reset captcha when toggling - it's still valid
        // and prevents unnecessary captcha solving
    };

    return (
        <div className="auth-container">
            <div className="auth-form">
                <div className="auth-header">
                    <h2 className="auth-title">{isLogin ? 'Welcome Back' : 'Create Account'}</h2>
                    <p className="auth-subtitle">
                        {isLogin ? 'Sign in to your account' : 'Sign up for a new account'}
                    </p>
                </div>
                
                {error && (
                    <div className={`alert ${error.includes('successful') ? 'alert-success' : 'alert-danger'}`}>
                        {error}
                    </div>
                )}
                
                <form onSubmit={handleSubmit} className="auth-form-content">
                    {!isLogin && (
                        <div className="form-group">
                            <label htmlFor="name" className="form-label">Full Name</label>
                            <input
                                id="name"
                                type="text"
                                className="form-input"
                                placeholder="Enter your full name"
                                value={name}
                                onChange={(e) => setName(e.target.value)}
                                required
                            />
                        </div>
                    )}
                    
                    <div className="form-group">
                        <label htmlFor="email" className="form-label">Email</label>
                        <input
                            id="email"
                            type="email"
                            className="form-input"
                            placeholder="Enter your email"
                            value={email}
                            onChange={(e) => setEmail(e.target.value)}
                            required
                        />
                    </div>
                    
                    <div className="form-group">
                        <label htmlFor="password" className="form-label">Password</label>
                        <input
                            id="password"
                            type="password"
                            className="form-input"
                            placeholder="Enter your password"
                            value={password}
                            onChange={(e) => setPassword(e.target.value)}
                            required
                        />
                    </div>
                    
                    <div className="form-group captcha-group">
                        <ReCAPTCHA
                            ref={recaptchaRef}
                            sitekey={process.env.REACT_APP_RECAPTCHA_SITE_KEY || "6LdMSUgrAAAAAFKCwbzfd18UmzlY7aez137XtsJh"}
                            onChange={handleCaptchaChange}
                            theme="light"
                        />
                        {!captchaToken && (
                            <p className="captcha-hint">Please complete the captcha verification</p>
                        )}
                    </div>
                    
                    <button 
                        type="submit" 
                        className="auth-submit-btn"
                        disabled={loading || !captchaToken}
                    >
                        {loading ? (
                            <span className="loading-spinner">
                                <span className="spinner"></span>
                                Processing...
                            </span>
                        ) : (
                            isLogin ? 'Sign In' : 'Create Account'
                        )}
                    </button>
                </form>
                
                <div className="auth-toggle">
                    <p className="toggle-text">
                        {isLogin ? "Don't have an account?" : "Already have an account?"}
                    </p>
                    <button 
                        type="button" 
                        className="toggle-btn"
                        onClick={toggleAuthMode}
                        disabled={loading}
                    >
                        {isLogin ? 'Sign Up' : 'Sign In'}
                    </button>
                </div>
            </div>
        </div>
    );
};

export default AuthPage;
