import React from 'react';
import { Container,Navbar, Row, Col, Button, Image } from 'react-bootstrap';
import { useNavigate } from 'react-router-dom';
import logo from '../assets/care-her_v5.png';
import sarahMomin from '../assets/sarah-momin.jpg';

const DoctorConsult = () => {
  const navigate = useNavigate();

  return (
    <div className="doctor-consult-page">
      {/* Header/Navbar */}
      <Navbar bg="white" expand="lg" className="py-3">
        <Container>
          <Navbar.Brand href="/">
            <img 
              src={logo}
              height="40" 
              className="d-inline-block align-top"
              alt="CareHer Logo"
            />
          </Navbar.Brand>
        </Container>
      </Navbar>

      {/* Doctor Information */}
      <Container className="text-center py-5">
        <h2 className="mb-4">Dr. Pooja Jain is waiting for you</h2>
        
        <div className="doctor-avatar mb-3">
          <Image 
            src={sarahMomin}
            roundedCircle 
            style={{ 
              width: '150px', 
              height: '150px',
              border: '5px solid #f8f9fa',
              boxShadow: '0 0 10px rgba(0,0,0,0.1)'
            }}
          />
        </div>
        
        <h3>Dr. Pooja Jain, Gynecologist</h3>
        <h5 className="text-muted mb-4">M.B.B.S, D.G.O, D.N.B</h5>
        
        <Container className="w-75">
          <p style={{ fontSize: '16px', lineHeight: '1.6' }}>
            Dr. Pooja has specialized in Fetal Medicine and is an expert in overall Obstetric and Gynaecological care with 8+ years of experience.
          </p>
        </Container>
        
        <div className="my-4">
          <span 
            className="p-2 px-4" 
            style={{ 
              backgroundColor: '#f0f0f0', 
              borderRadius: '20px',
              color: '#666'
            }}
          >
            Available Immediately
          </span>
        </div>
        
        <div className="mt-5 pt-5">
          <Button 
            style={{
              backgroundColor: '#FF5A5F',
              border: 'none',
              borderRadius: '5px',
              padding: '10px',
              width: '80%',
              maxWidth: '600px',
              fontSize: '18px',
              fontWeight: 'bold'
            }}
            onClick={() => alert('Consultation process started!')}
          >
            Proceed to the Consultation
          </Button>
        </div>
      </Container>
    </div>
  );
};

export default DoctorConsult;
