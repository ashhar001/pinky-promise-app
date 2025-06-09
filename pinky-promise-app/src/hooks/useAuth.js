// src/hooks/useAuth.js
import { useState, useEffect, useCallback } from 'react';
import axiosInstance from '../api/axiosConfig';

export const useAuth = () => {
    const [isAuthenticated, setIsAuthenticated] = useState(false);
    const [loading, setLoading] = useState(true);

    // Check authentication status
    const checkAuthStatus = useCallback(() => {
        const accessToken = localStorage.getItem('accessToken');
        const refreshToken = localStorage.getItem('refreshToken');
        
        if (accessToken && refreshToken) {
            setIsAuthenticated(true);
        } else {
            setIsAuthenticated(false);
        }
        setLoading(false);
    }, []);

    // Logout function
    const logout = useCallback(async () => {
        try {
            const refreshToken = localStorage.getItem('refreshToken');
            
            if (refreshToken) {
                // Call backend logout endpoint to blacklist token
                await axiosInstance.post('/api/auth/logout/', {
                    refresh_token: refreshToken
                });
            }
        } catch (error) {
            console.error('Logout error:', error);
            // Continue with logout even if backend call fails
        } finally {
            // Clear tokens from localStorage
            localStorage.removeItem('accessToken');
            localStorage.removeItem('refreshToken');
            
            // Update authentication state
            setIsAuthenticated(false);
            
            // Dispatch auth state change event
            window.dispatchEvent(new CustomEvent('authStateChanged'));
        }
    }, []);

    // Listen for auth state changes
    useEffect(() => {
        const handleAuthStateChange = () => {
            checkAuthStatus();
        };

        // Initial check
        checkAuthStatus();

        // Listen for custom auth events
        window.addEventListener('authStateChanged', handleAuthStateChange);
        
        // Listen for localStorage changes (for multi-tab logout)
        window.addEventListener('storage', (e) => {
            if (e.key === 'accessToken' || e.key === 'refreshToken') {
                checkAuthStatus();
            }
        });

        return () => {
            window.removeEventListener('authStateChanged', handleAuthStateChange);
            window.removeEventListener('storage', checkAuthStatus);
        };
    }, [checkAuthStatus]);

    return {
        isAuthenticated,
        loading,
        logout,
        checkAuthStatus
    };
};
