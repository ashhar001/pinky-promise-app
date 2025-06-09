// src/api/axiosConfig.js
import axios from 'axios';

const axiosInstance = axios.create({
    baseURL: 'http://localhost:5001',
    timeout: 10000,
    headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
    },
});

// Request interceptor to add auth token
axiosInstance.interceptors.request.use(
    (config) => {
        const token = localStorage.getItem('accessToken');
        if (token) {
            config.headers.Authorization = `Bearer ${token}`;
        }
        return config;
    },
    (error) => {
        return Promise.reject(error);
    }
);

// Response interceptor to handle errors and logout
axiosInstance.interceptors.response.use(
    (response) => response,
    (error) => {
        if (error.code === 'ECONNABORTED') {
            console.error('Request timeout - server took too long to respond');
            return Promise.reject(new Error('Request timeout. Please try again.'));
        }

        if (error.response?.status === 401) {
            // Handle unauthorized access - clear tokens and redirect
            localStorage.removeItem('accessToken');
            localStorage.removeItem('refreshToken');
            
            // Dispatch custom event for logout
            window.dispatchEvent(new CustomEvent('authStateChanged'));
            
            // Only redirect if not already on auth page
            if (window.location.pathname !== '/auth') {
                window.location.href = '/auth';
            }
        }

        return Promise.reject(error);
    }
);

export default axiosInstance;
