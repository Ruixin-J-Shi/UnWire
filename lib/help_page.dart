/// HelpPage provides basic FAQ and contact info for the users.
/// Accessibility:
/// - The page provides headings for FAQs and a contact section.
/// - Each FAQ question is a button that, when tapped, expands to show the answer.
/// - Ensure that color contrast and semantic labels are sufficient.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HelpPage extends StatefulWidget {
  const HelpPage({Key? key}) : super(key: key);

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  // A simpler FAQ list
  // Each entry: { "question": "...", "answer": "...", "expanded": bool }
  List<Map<String, dynamic>> faqs = [
    {
      "question": "How do I connect to a nearby device?",
      "answer":
          "To connect, ensure you have granted required permissions and tapped 'Start Discovery'.",
      "expanded": false
    },
    {
      "question": "How do I send a message?",
      "answer":
          "Once connected, simply type your message in the text field and tap 'Send'.",
      "expanded": false
    },
    {
      "question": "How do I change my display name or image?",
      "answer":
          "Return to the login screen and select a new name or image before starting the chat.",
      "expanded": false
    },
  ];

  int currentTab = 1; // 1 = FAQ, 2 = Contact

  Widget buildFaqItem(Map<String, dynamic> faq) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: const Color(0xff383f4b), borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                faq["expanded"] = !faq["expanded"];
              });
            },
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    faq["question"],
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    semanticsLabel: 'FAQ question: ${faq["question"]}',
                  ),
                ),
                Icon(
                  faq["expanded"]
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: Colors.white,
                  semanticLabel:
                      faq["expanded"] ? 'Collapse answer' : 'Expand answer',
                ),
              ],
            ),
          ),
          if (faq["expanded"])
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                faq["answer"],
                style: const TextStyle(color: Colors.white, fontSize: 12),
                semanticsLabel: 'FAQ answer: ${faq["answer"]}',
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Accessibility: Back arrow has a semantic label
    return Scaffold(
      appBar: AppBar(
          shadowColor: Colors.transparent,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.transparent,
          leading: IconButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              icon: const Icon(
                Icons.arrow_back_ios,
                color: Colors.white,
                semanticLabel: 'Go back',
              )),
          title: const Text(
            "Help Center",
            style: TextStyle(color: Colors.white, fontSize: 15),
            semanticsLabel: 'Help Center title',
          ),
          systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light)),
      backgroundColor: const Color(0xff252d38),
      body: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                        onTap: () {
                          setState(() {
                            currentTab = 1;
                          });
                        },
                        child: Column(
                          children: [
                            const Text(
                              "FAQ",
                              style: TextStyle(color: Colors.white),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              height: currentTab == 1 ? 3 : 1,
                              width: double.infinity,
                              color: currentTab == 1
                                  ? const Color(0xff7687ff)
                                  : const Color(0xffaaaaaa),
                            )
                          ],
                        )),
                  ),
                  Expanded(
                      child: InkWell(
                          onTap: () {
                            setState(() {
                              currentTab = 2;
                            });
                          },
                          child: Column(
                            children: [
                              const Text(
                                "Contact us",
                                style: TextStyle(color: Colors.white),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                height: currentTab == 2 ? 3 : 1,
                                width: double.infinity,
                                color: currentTab == 2
                                    ? const Color(0xff7687ff)
                                    : const Color(0xffaaaaaa),
                              )
                            ],
                          )))
                ],
              ),
              const SizedBox(
                height: 20,
              ),
              if (currentTab == 1)
                Expanded(
                  child: ListView.builder(
                    itemCount: faqs.length,
                    itemBuilder: (context, index) {
                      return buildFaqItem(faqs[index]);
                    },
                  ),
                )
              else
                // Contact Us tab
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Contact Us",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                        semanticsLabel: 'Contact Us heading',
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 100,
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10)),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Semantics(
                            label: 'Contact message input field',
                            child: const TextField(
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: 'Enter your message or issue here',
                              ),
                              maxLines: 5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () {
                          // In a real app, you could send message to support.
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Message sent!")));
                        },
                        child: const Text(
                          "Send",
                          semanticsLabel: 'Send contact message',
                        ),
                      ),
                    ],
                  ),
                )
            ],
          )),
    );
  }
}
