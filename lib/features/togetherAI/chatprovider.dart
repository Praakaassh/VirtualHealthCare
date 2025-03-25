import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ChatMessage {
  final String role;
  final String content;
  final String timestamp;

  ChatMessage({
    required this.role, 
    required this.content,
    String? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toJson() => {
    'role': role,
    'content': content,
    'timestamp': timestamp,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role'],
      content: json['content'],
      timestamp: json['timestamp'],
    );
  }
}

class ChatProvider with ChangeNotifier {
  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  bool _isLoading = false;
  final String _storageKey = 'chat_history';
  
  ChatProvider() {
    _loadMessages();
  }

  List<ChatMessage> get messages => _messages;
  TextEditingController get textController => _textController;
  bool get isLoading => _isLoading;

  Future<void> _loadMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? storedMessages = prefs.getString(_storageKey);
      
      if (storedMessages != null) {
        final List<dynamic> decodedMessages = jsonDecode(storedMessages);
        _messages.clear();
        _messages.addAll(
          decodedMessages.map((msg) => ChatMessage.fromJson(msg)).toList()
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading messages: $e');
    }
  }

  Future<void> _saveMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encodedMessages = jsonEncode(
        _messages.map((msg) => msg.toJson()).toList()
      );
      await prefs.setString(_storageKey, encodedMessages);
    } catch (e) {
      debugPrint('Error saving messages: $e');
    }
  }

  Future<void> sendMessage() async {
    if (_textController.text.trim().isEmpty) return;

    final userMessage = _textController.text;
    _messages.add(ChatMessage(role: 'user', content: userMessage));
    _textController.clear();
    await _saveMessages();
    
    _isLoading = true;
    notifyListeners();

    const apiKey = "8cda88c94eff32917f4c1bb45dc6eacb4c68e8725149fc1b75a06482779d6484";
    const url = 'https://api.together.xyz/v1/chat/completions';

    List<Map<String, String>> apiMessages = [
      {
        'role': 'system',
        'content': 'You are a medical assistant that helps users identify possible diseases based on their symptoms.'
      },
    ];

    for (var message in _messages) {
      apiMessages.add({'role': message.role, 'content': message.content});
    }

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'meta-llama/Llama-3.3-70B-Instruct-Turbo',
          'messages': apiMessages,
          'temperature': 0.7,
          'max_tokens': 500,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiMessage = data['choices'][0]['message']['content'];
        _messages.add(ChatMessage(role: 'assistant', content: aiMessage));
        await _saveMessages();
      } else {
        _messages.add(ChatMessage(
          role: 'assistant',
          content: 'Error: Failed to get a response. Status code: ${response.statusCode}',
        ));
        await _saveMessages();
      }
    } catch (e) {
      _messages.add(ChatMessage(
        role: 'assistant',
        content: 'Error: Failed to send message. ${e.toString()}',
      ));
      await _saveMessages();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> clearChat() async {
    _messages.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    notifyListeners();
  }

  Future<void> clearOnLogout() async {
    await clearChat();
    _textController.clear();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}