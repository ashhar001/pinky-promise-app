// Step 3: Create UnauthorizedPage component (src/components/UnauthorizedPage.js)
import React from 'react';
import { Button, Container } from 'react-bootstrap';
import { useNavigate } from 'react-router-dom';

const UnauthorizedPage = () => {
  const navigate = useNavigate();
  
  return (
    <Container className="text-center mt-5">
      <h2 className="mb-4">🔒 Authentication Required</h2>
      <p className="lead">Please login to access the chat feature</p>
      <Button 
        variant="primary" 
        onClick={() => navigate('/auth')}
        className="mt-3"
      >
        Go to Login
      </Button>
    </Container>
  );
};

export default UnauthorizedPage;
