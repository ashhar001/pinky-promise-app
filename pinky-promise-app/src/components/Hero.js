import React from 'react';
import { Container, Row, Col, Button } from 'react-bootstrap';
import chatImage from '../assets/chat-image.png';
import { useNavigate } from 'react-router-dom';

function Hero() {

    const navigate = useNavigate();

    const handleConsultClick = () => {
      navigate('/consult');
    };


  return (
    <div className="hero-section py-5">
      <Container>
        <Row className="align-items-center">
          <Col lg={6} className="hero-text">
            <h1 className="mb-0">
              <span className="purple-text">Affordable and </span> 
              Quality Care
            </h1>
            <h1 className="mb-0">
              by <span className="purple-text">Judgement Free</span>
            </h1>
            <h1 className="mb-4">Gynaecologists</h1>
            
            <h5 className="mt-4">
              Talk to a Doctor Now - <span className="purple-text">No Waiting</span>
            </h5>
            
            <div className="hero-cta mt-4">
              <Button className="consult-button" onClick={handleConsultClick}>
                Consult Now
              </Button>
              <span className="ms-4">Starting @ ₹99 Only</span>
            </div>
          </Col>
          <Col lg={6}>
            <img 
              src={chatImage}
              alt="Doctor Chat Interface" 
              className="img-fluid"
            />
          </Col>
        </Row>
      </Container>
    </div>
  );
}

export default Hero;
