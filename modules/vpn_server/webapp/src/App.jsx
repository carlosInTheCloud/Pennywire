import React, { useState, useEffect } from 'react';
import { Amplify } from 'aws-amplify';
import { Authenticator } from '@aws-amplify/ui-react';
import { fetchAuthSession } from 'aws-amplify/auth';
import { Container, Menu, Table, Button, Header, Icon, Modal, Form, Segment, Message } from 'semantic-ui-react';
import nacl from 'tweetnacl';
import { encodeBase64 } from 'tweetnacl-util';
import awsExports from './aws-exports';
import './App.css';

Amplify.configure(awsExports);

function App() {
  const [clients, setClients] = useState([]);
  const [loading, setLoading] = useState(false);
  const [modalOpen, setModalOpen] = useState(false);
  const [newClientName, setNewClientName] = useState('');
  
  const [generatedConfig, setGeneratedConfig] = useState(null);

  const [serverInfo, setServerInfo] = useState({ ip: "VPN_SERVER_IP", pubKey: "SERVER_PUB_KEY" });

  const fetchClients = async () => {
    try {
      setLoading(true);
      const session = await fetchAuthSession();
      const token = session.tokens.idToken.toString();
      
      const response = await fetch(awsExports.api_endpoint + '/clients', {
        headers: { Authorization: `Bearer ${token}` }
      });
      if (response.ok) {
        const data = await response.json();
        const activeClients = [];
        let fetchedServerInfo = { ...serverInfo };
        
        (data.clients || []).forEach(c => {
          if (c.PublicKey === "SERVER_INFO") {
            fetchedServerInfo = { ip: c.ServerIp, pubKey: c.ServerPubKey };
          } else {
            activeClients.push(c);
          }
        });
        
        setServerInfo(fetchedServerInfo);
        setClients(activeClients);
      }
    } catch (err) {
      console.error("Error fetching clients", err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchClients();
  }, []);

  const handleGenerateKey = async () => {
    if (!newClientName) return;
    
    // Generate X25519 keypair securely in the browser
    const keypair = nacl.box.keyPair();
    const privateKey = encodeBase64(keypair.secretKey);
    const publicKey = encodeBase64(keypair.publicKey);
    
    try {
      const session = await fetchAuthSession();
      const token = session.tokens.idToken.toString();
      
      const response = await fetch(awsExports.api_endpoint + '/clients', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`
        },
        body: JSON.stringify({
          clientName: newClientName,
          publicKey: publicKey
        })
      });
      
      if (response.ok) {
        const data = await response.json();
        const clientIp = data.ClientIp || "10.8.0.x";
        
        const configStr = `[Interface]
PrivateKey = ${privateKey}
Address = ${clientIp}/32
DNS = 1.1.1.1

[Peer]
PublicKey = ${serverInfo.pubKey}
AllowedIPs = 0.0.0.0/0
Endpoint = ${serverInfo.ip}:51820
PersistentKeepalive = 25`;
        
        setGeneratedConfig(configStr);
        fetchClients();
      }
    } catch (err) {
      console.error("Error creating client", err);
    }
  };

  const handleRevoke = async (pubKey) => {
    try {
      const session = await fetchAuthSession();
      const token = session.tokens.idToken.toString();
      
      await fetch(`${awsExports.api_endpoint}/clients/${encodeURIComponent(pubKey)}`, {
        method: 'DELETE',
        headers: { Authorization: `Bearer ${token}` }
      });
      fetchClients();
    } catch (err) {
      console.error("Error revoking client", err);
    }
  };

  const downloadConfig = () => {
    const element = document.createElement("a");
    const file = new Blob([generatedConfig], {type: 'text/plain'});
    element.href = URL.createObjectURL(file);
    element.download = `${newClientName.replace(/\s+/g, '_')}.conf`;
    document.body.appendChild(element); // Required for this to work in FireFox
    element.click();
  };

  return (
    <Authenticator>
      {({ signOut, user }) => (
        <Container style={{ paddingTop: '2em' }}>
          <Menu inverted attached="top" className="glass-segment">
            <Menu.Item header>
              <Icon name="shield" />
              VPN Key Manager
            </Menu.Item>
            <Menu.Menu position="right">
              <Menu.Item>
                <Icon name="user" /> {user?.signInDetails?.loginId || user?.username}
              </Menu.Item>
              <Menu.Item onClick={signOut}>
                Sign Out
              </Menu.Item>
            </Menu.Menu>
          </Menu>

          <Segment attached inverted className="glass-segment">
            <Header as="h2" style={{ color: 'rgba(255,255,255,0.9)' }}>
              Active Clients
              <Button primary floated="right" onClick={() => {setModalOpen(true); setGeneratedConfig(null); setNewClientName('');}}>
                <Icon name="plus" /> Issue New Key
              </Button>
            </Header>
            
            <Table inverted celled padded style={{ background: 'rgba(0,0,0,0.2)' }}>
              <Table.Header>
                <Table.Row>
                  <Table.HeaderCell>Client Name</Table.HeaderCell>
                  <Table.HeaderCell>IP Address</Table.HeaderCell>
                  <Table.HeaderCell>Public Key</Table.HeaderCell>
                  <Table.HeaderCell>Action</Table.HeaderCell>
                </Table.Row>
              </Table.Header>
              <Table.Body>
                {clients.length === 0 && (
                  <Table.Row>
                    <Table.Cell colSpan="4" textAlign="center">No active clients found.</Table.Cell>
                  </Table.Row>
                )}
                {clients.map(c => (
                  <Table.Row key={c.PublicKey}>
                    <Table.Cell>{c.ClientName}</Table.Cell>
                    <Table.Cell><code>{c.ClientIp}</code></Table.Cell>
                    <Table.Cell style={{ maxWidth: '200px', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                      <code>{c.PublicKey}</code>
                    </Table.Cell>
                    <Table.Cell>
                      <Button color="red" size="small" onClick={() => handleRevoke(c.PublicKey)}>
                        Revoke
                      </Button>
                    </Table.Cell>
                  </Table.Row>
                ))}
              </Table.Body>
            </Table>
          </Segment>

          <Modal size="small" open={modalOpen} onClose={() => setModalOpen(false)}>
            <Modal.Header style={{ background: '#1b1c1d', color: '#fff', borderBottom: '1px solid #333' }}>
              Issue New WireGuard Key
            </Modal.Header>
            <Modal.Content style={{ background: '#242526', color: '#fff' }}>
              {!generatedConfig ? (
                <Form inverted>
                  <Form.Input 
                    label="Client Name" 
                    placeholder="e.g. iPhone, Work Laptop" 
                    value={newClientName}
                    onChange={(e) => setNewClientName(e.target.value)}
                  />
                </Form>
              ) : (
                <Message positive style={{ background: 'rgba(33, 186, 69, 0.1)', color: '#21ba45', border: '1px solid #21ba45' }}>
                  <Message.Header>Success! Client key generated.</Message.Header>
                  <p>
                    Your private key was generated locally in this browser. <b>It has not been saved anywhere.</b><br/>
                    Please download your configuration file now. If you lose it, you will need to revoke this client and generate a new one.
                  </p>
                  <Button icon labelPosition="left" color="green" onClick={downloadConfig} fluid>
                    <Icon name="download" />
                    Download {newClientName.replace(/\s+/g, '_')}.conf
                  </Button>
                </Message>
              )}
            </Modal.Content>
            <Modal.Actions style={{ background: '#1b1c1d', borderTop: '1px solid #333' }}>
              <Button inverted onClick={() => setModalOpen(false)}>Close</Button>
              {!generatedConfig && (
                <Button primary onClick={handleGenerateKey} disabled={!newClientName}>
                  Generate
                </Button>
              )}
            </Modal.Actions>
          </Modal>

        </Container>
      )}
    </Authenticator>
  );
}

export default App;
