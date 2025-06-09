// Step 1: Create ChatPage component (src/components/ChatPage.js)
import React from 'react';
import { Container, Card, Form, Button } from 'react-bootstrap';

const ChatPage = () => {
  return (
    <Container className="my-5">
      <Card>
        <Card.Header as="h5">CareHer Chat</Card.Header>
        <Card.Body style={{ height: '500px', overflowY: 'auto' }}>
          {/* Chat messages will go here */}
          <div className="text-muted text-center mt-5">Chat feature coming soon!</div>
        </Card.Body>
        <Card.Footer>
          <Form className="d-flex gap-2">
            <Form.Control
              type="text"
              placeholder="Type your message..."
              disabled
            />
            <Button variant="primary" disabled>
              Send
            </Button>
          </Form>
        </Card.Footer>
      </Card>
    </Container>
  );
};

export default ChatPage;
