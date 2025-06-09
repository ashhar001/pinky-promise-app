// src/services/authService.js
import axios from 'axios';

const API_URL = 'http://localhost:8000/api/';

const register = async (username, email, password, password2) => {
  try {
    const response = await axios.post(API_URL + 'accounts/register/', {
      username,
      email,
      password,
      password2
    });
    if (response.data.access) {
      localStorage.setItem('user', JSON.stringify(response.data));
    }
    return response.data;
  } catch (error) {
    throw error.response?.data || { message: "Registration failed" };
  }
};

const login = async (username, password) => {
  try {
    const response = await axios.post(API_URL + 'token/', {
      username,
      password
    });
    if (response.data.access) {
      localStorage.setItem('user', JSON.stringify(response.data));
    }
    return response.data;
  } catch (error) {
    throw error.response?.data || { message: "Login failed" };
  }
};

const logout = () => {
  localStorage.removeItem('user');
};

const getCurrentUser = () => {
  return JSON.parse(localStorage.getItem('user'));
};

const authService = {
  register,
  login,
  logout,
  getCurrentUser
};

export default authService;
