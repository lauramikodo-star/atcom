import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class RechargeScreen extends StatefulWidget {
  final bool scanMode;
  
  RechargeScreen({this.scanMode = false});

  @override
  _RechargeScreenState createState() => _RechargeScreenState();
}

class _RechargeScreenState extends State<RechargeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _voucherController = TextEditingController();
  
  bool _isLoading = false;
  String? _error;
  String? _successMessage;
  bool _isProcessingOCR = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _voucherController.dispose();
    super.dispose();
  }

  Future<void> _handleRecharge() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _successMessage = null;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final result = await apiService.recharge(
        _phoneController.text.trim(),
        _voucherController.text.trim(),
      );

      if (result.success) {
        setState(() {
          _successMessage = result.message;
          _voucherController.clear();
        });
        
        // Show success dialog
        _showSuccessDialog(result);
      } else {
        setState(() {
          _error = result.message;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Network error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _scanVoucher() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );

    if (image != null) {
      setState(() {
        _isProcessingOCR = true;
        _error = null;
      });

      try {
        final apiService = Provider.of<ApiService>(context, listen: false);
        final result = await apiService.extractVoucherCode(image.path);

        if (result.startsWith('Error:')) {
          setState(() {
            _error = result;
          });
        } else {
          setState(() {
            _voucherController.text = result;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Voucher code extracted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        setState(() {
          _error = 'OCR Error: ${e.toString()}';
        });
      } finally {
        setState(() {
          _isProcessingOCR = false;
        });
      }
    }
  }

  void _showSuccessDialog(RechargeResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 8),
            Text('Success!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(result.message),
            SizedBox(height: 16),
            Text('Transaction Details:', style: TextStyle(fontWeight: FontWeight.bold)),
            ...result.response.entries.map((entry) => 
              Text('${entry.key}: ${entry.value}')
            ).toList(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Return to dashboard
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.scanMode ? 'Scan Voucher' : 'Recharge'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                widget.scanMode ? 'Scan & Recharge' : 'Enter Recharge Details',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Recharge your Algeria Telecom service',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 32),

              // Phone Number Field
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  hintText: '0xxxxxxxxx',
                  prefixIcon: Icon(Icons.phone, color: Color(0xFF2196F3)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Color(0xFF2196F3)),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter phone number';
                  }
                  if (!value.startsWith('0') || value.length < 9) {
                    return 'Please enter a valid phone number';
                  }
                  return null;
                },
              ),
              SizedBox(height: 24),

              // Voucher Code Field
              TextFormField(
                controller: _voucherController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Voucher Code',
                  hintText: '16-digit voucher code',
                  prefixIcon: Icon(Icons.credit_card, color: Color(0xFF2196F3)),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isProcessingOCR)
                        Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      IconButton(
                        icon: Icon(Icons.camera_alt, color: Color(0xFF2196F3)),
                        onPressed: _isProcessingOCR ? null : _scanVoucher,
                        tooltip: 'Scan voucher',
                      ),
                    ],
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Color(0xFF2196F3)),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter voucher code';
                  }
                  if (value.length != 16) {
                    return 'Voucher code must be 16 digits';
                  }
                  return null;
                },
              ),
              SizedBox(height: 32),

              // Error Message
              if (_error != null)
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(color: Colors.red[700]),
                        ),
                      ),
                    ],
                  ),
                ),

              // Success Message
              if (_successMessage != null)
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _successMessage!,
                          style: TextStyle(color: Colors.green[700]),
                        ),
                      ),
                    ],
                  ),
                ),

              // Recharge Button
              SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleRecharge,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF2196F3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Processing...'),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.credit_card, size: 24),
                            SizedBox(width: 8),
                            Text(
                              'Recharge Now',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              // Instructions
              SizedBox(height: 32),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey[200]!),
                ),
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Instructions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: 16),
                      _buildInstructionItem(
                        '1. Enter your phone number (starting with 0)',
                        Icons.phone,
                      ),
                      _buildInstructionItem(
                        '2. Enter the 16-digit voucher code',
                        Icons.credit_card,
                      ),
                      _buildInstructionItem(
                        '3. Or use camera to scan the voucher',
                        Icons.camera_alt,
                      ),
                      _buildInstructionItem(
                        '4. Click Recharge to complete',
                        Icons.check_circle,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionItem(String text, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Color(0xFF2196F3)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }
}