import React from 'react';
import { Container, Row, Col, Button, Card } from 'react-bootstrap';
import pooja from '../assets/pooja-jain.jpg';
import sarahMomin from '../assets/sarah-momin.jpg';
import yash from '../assets/yash-bahuguna.jpg';
import preeti from '../assets/preeti-thakur.jpg';

const experts = [
  {
    name: "Dr Pooja Jain",
    title: "MBBS, D.G.O, D.N.B",
    description: `Dr. Pooja has over 8 years of experience as a gynaecologist in some of India’s premier medical institutions like Jaslok Hospital, MGM Hospital and NWMH Parel.`,
    reg: "2015/05/2839",
    regLabel: "Medical Registration No:",
    image: pooja, // Replace with your image path
  },
  {
    name: "Dr Sarah Momin",
    title: "MBBS, D.G.O",
    description: `Dr. Sarah is an obstetrician & Gynecologist with 6+ years of experience, with an MBBS from Rajiv Gandhi Medical College and a D.G.O from HBT Municipal Hospital. She has trained at Nida Multispeciality hospital, and is registered with MMC.`,
    reg: "2019/04/2373",
    regLabel: "Medical Registration No:",
    image: sarahMomin, // Replace with your image path
  },
  {
    name: "Dr. Yash Bahuguna",
    title: "MBBS, MS, DNB",
    description: `Dr Yash is a Gynecologist with 6+ years of experience at PSRI Hospital, Indraprastha Apollo Hospital, HBTMC, Dr. RN Cooper Hospital, Government Medical College, Akola. He specializes in hormonal health and PCOS and holds an ICOG certificate in PCOS.`,
    reg: "110281",
    regLabel: "Medical Registration No:",
    image: yash, // Replace with your image path
  },
  {
    name: "Preeti Thakur",
    title: "M. Sc. (Food and nutrition), CDE (Certified Diabetes Educator), IDA Member",
    description: `Preeti has over 6 years of experience in hormone related disorders and infertility issues.`,
    reg: null,
    regLabel: null,
    image: preeti, // Replace with your image path
  },
];

const ExpertSection = () => (
  <div style={{ background: "#fdf7f7", padding: "40px 0", position: "relative" }}>
    <Container>
      <Row className="justify-content-center mb-4">
        <Col xs="auto">
          <Button
            variant="outline-secondary"
            style={{
              background: "#f3e7fa",
              color: "#7c4bc7",
              border: "none",
              borderRadius: "20px",
              fontWeight: "bold",
              padding: "8px 28px",
              fontSize: "18px"
            }}
          >
            <span style={{ marginRight: "8px" }}>→</span> More Stories
          </Button>
        </Col>
      </Row>
      <Row>
        {experts.map((expert, idx) => (
          <Col md={3} sm={6} xs={12} key={idx} className="mb-4 d-flex">
            <Card className="w-100 border-0 bg-transparent text-center">
              <Card.Img
                variant="top"
                src={expert.image}
                alt={expert.name}
                style={{
                  height: "220px",
                  objectFit: "cover",
                  borderRadius: "0",
                  background: "#fff"
                }}
              />
              <Card.Body>
                <Card.Title as="h5" style={{ fontWeight: "bold", marginBottom: "0.25rem" }}>
                  {expert.name}
                </Card.Title>
                <Card.Subtitle className="mb-2 text-muted" style={{ fontWeight: "bold", fontSize: "15px" }}>
                  {expert.title}
                </Card.Subtitle>
                <Card.Text style={{ fontSize: "15px", minHeight: "120px" }}>
                  {expert.description}
                </Card.Text>
                {expert.reg && (
                  <div style={{ color: "#ff5a5f", fontWeight: "bold", fontSize: "15px" }}>
                    <span style={{ fontStyle: "italic" }}>{expert.regLabel}</span> {expert.reg}
                  </div>
                )}
              </Card.Body>
            </Card>
          </Col>
        ))}
      </Row>
    </Container>

    {/* Floating Contact Button */}

  </div>
);

export default ExpertSection;
