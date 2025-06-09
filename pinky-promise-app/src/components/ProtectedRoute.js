// src/components/ProtectedRoute.js
import React from 'react';
import { Navigate, Outlet } from 'react-router-dom';

const ProtectedRoute = () => {
  // Check if user is authenticated with JWT
  const isAuthenticated = localStorage.getItem('accessToken') !== null;
  
  // Redirect to unauthorized page if not authenticated
  return isAuthenticated ? <Outlet /> : <Navigate to="/unauthorized" />;
};

export default ProtectedRoute;
