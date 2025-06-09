import React from 'react';
import {  Button } from 'react-bootstrap';



const ContactCustmerSprt = () => (
  <div style={{ background: "#fdf7f7", padding: "40px 0", position: "relative" }}>
    {/* Floating Contact Button */}
    <Button
      variant="success"
      style={{
        position: "fixed",
        bottom: "30px",
        right: "30px",
        borderRadius: "30px",
        padding: "14px 28px",
        fontWeight: "bold",
        fontSize: "18px",
        background: "#d4f8e8",
        color: "#1a8a5b",
        border: "none",
        boxShadow: "0 2px 12px rgba(0,0,0,0.08)",
        zIndex: 1000
      }}
    >
      <svg width="22" height="22" fill="currentColor" style={{ marginRight: "8px" }}>
        <circle cx="11" cy="11" r="10" fill="#1a8a5b" />
        <path d="M7 11l3 3 5-5" stroke="#fff" strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round"/>
      </svg>
      Contact Customer Support
    </Button>
  </div>
);

export default ContactCustmerSprt;
