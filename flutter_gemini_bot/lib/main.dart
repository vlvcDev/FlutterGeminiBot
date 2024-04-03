// backgroundColor: const Color.fromARGB(255, 6, 41, 37)
// const Color.fromARGB(255, 4, 74, 66)

// import 'dart:html';

import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async{
  await dotenv.load(fileName: ".env"); // Load the environment variables
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 6, 35, 41)),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Ooga Booga'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _messageCount = 0;

  void incrementMessageCount() {
    setState(() {
      _messageCount++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Gemini-Lite",
            style: TextStyle(
              color: Theme.of(context).colorScheme.inverseSurface,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              fontFamily: 'Roboto',
            )),
        centerTitle: true,
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: ChatScreen(incrementMessageCount: incrementMessageCount),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            UserAccountsDrawerHeader(
              accountName: Text('Ooga Booga',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
              ),
              accountEmail: Text('ooga@booga.mail',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.normal,
                ),
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                backgroundImage: NetworkImage('https://i.imgur.com/1oqK8fJ.jpeg'),
              ),
            ),
            ListTile(
              title: Text('Messages sent: $_messageCount'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final VoidCallback incrementMessageCount;
  const ChatScreen({super.key, required this.incrementMessageCount});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final GenerativeModel model;
  late final ChatSession chat;
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _loading = false;



  @override
  void initState() {
    model = GenerativeModel(model: 'gemini-pro', apiKey: dotenv.env['API_KEY']!);
    chat = model.startChat();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    bool hasApiKey = dotenv.env['API_KEY'] != null && dotenv.env['API_KEY']!.isNotEmpty;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Padding(
        padding: const EdgeInsets.all(6.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: hasApiKey
                  ? ListView.builder(
                controller: _scrollController,
                itemBuilder: (context, idx) {
                  final content = chat.history.toList()[idx];
                  final text = content.parts.whereType<TextPart>().map<String>((e) => e.text).join('');
                  return MessageWidget(
                    text: text,
                    isFromUser: content.role == 'user',
                  );
                },
                itemCount: chat.history.length,
              )
                  : ListView(
                children: const [
                  Text('No API key found'),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                vertical: 6,
                horizontal: 12,
              ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(4),
            ),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _chatController,
                      autofocus: true,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.all(8),
                        hintText: 'Enter a prompt...',
                        hintStyle: TextStyle(
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: const BorderRadius.all(
                            Radius.circular(14),
                          ),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.inversePrimary,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: const BorderRadius.all(
                            Radius.circular(14),
                          ),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.surface,
                          ),
                        ),
                      ),
                      onFieldSubmitted: (String value) {
                        _sendChat(value);
                      },
                    ),
                  ),
                  const SizedBox.square(
                    dimension: 15,
                  ),
                  if (!_loading)
                    IconButton(
                      onPressed: () async {
                        _sendChat(_chatController.text);
                      },
                      icon: Icon(
                        Icons.send,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    )
                  else
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.secondary),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  Future<void> _sendChat(String message) async {
    setState(() => _loading = true);

    try {
      final response = await chat.sendMessage(Content.text(message));
      final text = response.text;
      if (text == null) {
        debugPrint('No response from API');
        return;
      }
      setState(() => _loading = false);
      widget.incrementMessageCount();
    } catch (e) {
      if (e is GenerativeAIException && e.message.contains('recitation')) {
        debugPrint('Your request was blocked by the API');
      } else {
        debugPrint('An error occurred');
      }
      debugPrint(e.toString());
    } finally {
      _chatController.clear();
      setState(() => _loading = false);
    }
  }
}

class MessageWidget extends StatelessWidget {
  final String text;
  final bool isFromUser;

  const MessageWidget({
    super.key,
    required this.text,
    required this.isFromUser,
  });
  
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: isFromUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Flexible(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isFromUser
                  ? Theme.of(context).colorScheme.inversePrimary
                  : Theme.of(context).colorScheme.surface,
            ),
            padding: const EdgeInsets.symmetric(
              vertical: 6,
              horizontal: 6,
            ),
            margin: const EdgeInsets.only(bottom: 8),
            child: MarkdownBody(
              selectable: true,
              data: text,
            ),
          ),
        ),
      ],
    );
  }
}