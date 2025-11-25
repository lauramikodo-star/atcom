import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../models/user_session.dart';

class AccountScreen extends StatefulWidget {
  @override
  _AccountScreenState createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  AccountDetails? _accountDetails;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAccountDetails();
  }

  Future<void> _loadAccountDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final details = await authService.getAccountDetails();
      
      setState(() {
        _accountDetails = details;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load account details: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentSession?.user;

    return Scaffold(
      appBar: AppBar(
        title: Text('Account Details'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadAccountDetails,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAccountDetails,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Profile Card
              _buildProfileCard(user),
              SizedBox(height: 24),

              // Account Information
              if (_isLoading)
                Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_error != null)
                _buildErrorCard(_error!)
              else if (_accountDetails != null)
                _buildAccountDetails(_accountDetails!)
              else
                _buildNoDataCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(UserData? user) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Color(0xFF2196F3),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(
                Icons.person,
                size: 40,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 16),
            Text(
              user?.fullName ?? 'Unknown User',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 8),
            Text(
              user?.email ?? 'No email',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Color(0xFF2196F3).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Color(0xFF2196F3).withOpacity(0.3)),
              ),
              child: Text(
                user?.type ?? 'Customer',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF2196F3),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountDetails(AccountDetails details) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Account Information',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        SizedBox(height: 16),
        
        // Personal Information
        _buildSectionCard(
          'Personal Information',
          [
            _buildDetailRow('Full Name', '${details.prenom} ${details.nom}'),
            _buildDetailRow('Email', details.email),
            _buildDetailRow('Phone', details.nd),
            _buildDetailRow('Mobile', details.mobile),
            _buildDetailRow('Address', details.adresse),
          ],
        ),
        SizedBox(height: 16),

        // Service Information
        _buildSectionCard(
          'Service Information',
          [
            _buildDetailRow('Offer', details.offre),
            _buildDetailRow('Type', details.type1),
            _buildDetailRow('Status', details.status),
            _buildDetailRow('Client ID', details.ncli),
            _buildDetailRow('Expiry Date', details.dateexp),
          ],
        ),
        SizedBox(height: 16),

        // Financial Information
        _buildSectionCard(
          'Financial Information',
          [
            _buildDetailRow('Balance', '${details.balance.toStringAsFixed(2)} DZD', 
              color: details.balance > 0 ? Colors.green : Colors.grey),
            _buildDetailRow('Credit', '${details.credit.toStringAsFixed(2)} DZD',
              color: Colors.blue),
            _buildDetailRow('Debt', '${details.dette.toStringAsFixed(2)} DZD',
              color: details.hasDebt ? Colors.red : Colors.grey),
            if (details.bonusVoixRestant != null)
              _buildDetailRow('Voice Bonus', '${details.bonusVoixRestant} min',
                color: Colors.purple),
          ],
        ),
        SizedBox(height: 16),

        // Status Indicators
        _buildStatusIndicators(details),
      ],
    );
  }

  Widget _buildSectionCard(String title, List<Widget> children) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: color ?? Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicators(AccountDetails details) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Account Status',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 16),
            _buildStatusRow(
              'Service Status',
              details.status,
              details.status.toLowerCase().contains('active') ? Colors.green : Colors.orange,
            ),
            _buildStatusRow(
              'Debt Status',
              details.hasDebt ? 'Outstanding Debt' : 'No Debt',
              details.hasDebt ? Colors.red : Colors.green,
            ),
            _buildStatusRow(
              'Expiry Status',
              details.isExpired ? 'Expired' : 'Active',
              details.isExpired ? Colors.red : Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String status, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.red[200]!),
      ),
      color: Colors.red[50],
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(Icons.error, color: Colors.red, size: 32),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                error,
                style: TextStyle(color: Colors.red[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDataCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.info, size: 48, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No account details available',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadAccountDetails,
                child: Text('Refresh'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}