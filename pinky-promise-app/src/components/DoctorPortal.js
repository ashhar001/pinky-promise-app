import React, { useState, useEffect } from 'react';
import { Container, Row, Col, Card, Badge, Button, Tab, Tabs, Alert } from 'react-bootstrap';

const DoctorPortal = () => {
    const [activePatients, setActivePatients] = useState([]);
    const [pendingRequests, setPendingRequests] = useState([]);
    const [selectedChat, setSelectedChat] = useState(null);
    const [error, setError] = useState(null);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        fetchPatientQueue();
        const interval = setInterval(fetchPatientQueue, 10000); // Poll every 10 seconds
        return () => clearInterval(interval);
    }, []);

    const fetchPatientQueue = async () => {
        try {
            const token = localStorage.getItem('access_token');
            if (!token) {
                setError('No authentication token found. Please login.');
                return;
            }

            const response = await fetch('/api/auth/doctor-queue/', {
                method: 'GET',
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'Content-Type': 'application/json'
                }
            });

            if (response.ok) {
                const data = await response.json();
                setActivePatients(data.active_patients || []);
                setPendingRequests(data.pending_requests || []);
                setError(null);
            } else if (response.status === 401) {
                setError('Authentication failed. Please login again.');
            } else if (response.status === 403) {
                setError('Access denied. Doctor privileges required.');
            } else {
                setError('Failed to load patient queue.');
            }
        } catch (err) {
            setError('Network error. Please check your connection.');
            console.error('Error fetching patient queue:', err);
        } finally {
            setLoading(false);
        }
    };

    if (loading) {
        return (
            <Container className="mt-4">
                <Card>
                    <Card.Body className="text-center">
                        <div className="spinner-border" role="status">
                            <span className="visually-hidden">Loading...</span>
                        </div>
                        <p className="mt-2">Loading doctor portal...</p>
                    </Card.Body>
                </Card>
            </Container>
        );
    }

    return (
        <Container fluid className="mt-4">
            {error && (
                <Alert variant="danger" dismissible onClose={() => setError(null)}>
                    {error}
                </Alert>
            )}
            
            <Row>
                <Col md={4}>
                    <Card>
                        <Card.Header>
                            <h5>Patient Queue</h5>
                            <Button variant="outline-primary" size="sm" onClick={fetchPatientQueue}>
                                Refresh
                            </Button>
                        </Card.Header>
                        <Card.Body>
                            <Tabs defaultActiveKey="active">
                                <Tab eventKey="active" title={`Active (${activePatients.length})`}>
                                    {activePatients.length === 0 ? (
                                        <p className="text-center text-muted mt-3">No active patients</p>
                                    ) : (
                                        activePatients.map(patient => (
                                            <Card key={patient.id} className="mb-2">
                                                <Card.Body className="p-2">
                                                    <div className="d-flex justify-content-between">
                                                        <span>{patient.user?.username || 'Patient'}</span>
                                                        <Badge bg="success">Active</Badge>
                                                    </div>
                                                    <small className="text-muted">
                                                        Assigned: {new Date(patient.created_at).toLocaleString()}
                                                    </small>
                                                    <br />
                                                    <Button 
                                                        size="sm" 
                                                        onClick={() => setSelectedChat(patient.chat_room)}
                                                        className="mt-1"
                                                        variant="primary"
                                                    >
                                                        Open Chat
                                                    </Button>
                                                </Card.Body>
                                            </Card>
                                        ))
                                    )}
                                </Tab>
                                <Tab eventKey="pending" title={`Pending (${pendingRequests.length})`}>
                                    {pendingRequests.length === 0 ? (
                                        <p className="text-center text-muted mt-3">No pending requests</p>
                                    ) : (
                                        pendingRequests.map(request => (
                                            <Card key={request.id} className="mb-2">
                                                <Card.Body className="p-2">
                                                    <div className="d-flex justify-content-between">
                                                        <span>{request.user?.username || 'Patient'}</span>
                                                        <Badge bg="warning">Pending</Badge>
                                                    </div>
                                                    <Button 
                                                        size="sm" 
                                                        variant="success"
                                                        className="mt-1"
                                                    >
                                                        Accept
                                                    </Button>
                                                </Card.Body>
                                            </Card>
                                        ))
                                    )}
                                </Tab>
                            </Tabs>
                        </Card.Body>
                    </Card>
                </Col>
                <Col md={8}>
                    {selectedChat ? (
                        <Card>
                            <Card.Header>
                                <h5>Chat with Patient</h5>
                            </Card.Header>
                            <Card.Body>
                                <p>Chat interface will be implemented here.</p>
                                <p>Selected chat: {selectedChat}</p>
                            </Card.Body>
                        </Card>
                    ) : (
                        <Card>
                            <Card.Body className="text-center">
                                <h5>Select a patient to start chatting</h5>
                                <p className="text-muted">Choose a patient from the queue to begin communication.</p>
                            </Card.Body>
                        </Card>
                    )}
                </Col>
            </Row>
        </Container>
    );
};

export default DoctorPortal;
