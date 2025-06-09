import React from 'react';
import { Container, Row, Col } from 'react-bootstrap';

function Testimonials() {
  const testimonials = [
    {
      name: 'Manvi Rana',
      age: '23',
      location: 'New Delhi, Delhi',
      quote: 'I swear to god I am never visiting a judgemental gynaecologist ever again in my entire life. Pinky Promise will',
    },
    {
      name: 'Prathima Hs',
      age: '25',
      location: 'Meerut, Uttar Pradesh',
      quote: 'One of the best and safest app ever it helps alot to cure my problem and now I\'m perfectly all right after consulting',
    },
    {
      name: 'Swarika',
      age: '32',
      location: 'Aligarh, Uttar Pradesh',
      quote: 'Happy mother of baby girl after failed IUI thanks to the services of I so happy and grateful',
    }
  ];

  return (
    <div className="testimonial-section py-5">
      <Container>
        <Row className="mb-4">
          <Col>
            <h2>Trusted by <span className="purple-text">150,000+</span></h2>
          </Col>
        </Row>
        <Row>
          {testimonials.map((testimonial, index) => (
            <Col md={4} key={index}>
              <div className="testimonial-card mb-4">
                <div className="quote-icon">❝</div>
                <h4>{testimonial.name}</h4>
                <p className="text-muted">{testimonial.age}, {testimonial.location}</p>
                <p>{testimonial.quote}</p>
              </div>
            </Col>
          ))}
        </Row>
      </Container>
    </div>
  );
}

export default Testimonials;
