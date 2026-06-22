import sys

with open('c:/Users/savya/OneDrive/Documents/Samanyudu TV/Mobile_App/Samanyudu-News_App/lib/screens/index_v2.dart', 'r', encoding='utf-8') as f:
    content = f.read()

with open('c:/Users/savya/OneDrive/Documents/Samanyudu TV/Mobile_App/Samanyudu-News_App/lib/screens/v2_ui_chunk.dart', 'r', encoding='utf-8') as f:
    chunk = f.read()

content = content.replace('class IndexScreen extends', 'class IndexScreenV2 extends')
content = content.replace('IndexScreen({', 'IndexScreenV2({')
content = content.replace('=> IndexScreenState();', '=> IndexScreenV2State();')
content = content.replace('class IndexScreenState extends State<IndexScreen>', 'class IndexScreenV2State extends State<IndexScreenV2>')

old_sig = "Widget build(BuildContext context) {"
new_sig = "Widget build(BuildContext context) {\n    return _buildNewUI(context);\n  }\n\n  Widget _oldBuild(BuildContext context) {"
if old_sig in content:
    content = content.replace(old_sig, new_sig, 1)

split_target = "class _MutedAdPlayer extends StatefulWidget {"
if split_target in content:
    parts = content.split(split_target, 1)
    sub_parts = parts[0].rsplit('}', 1)
    new_first_part = sub_parts[0] + chunk + '\n}\n\n'
    content = new_first_part + split_target + parts[1]
    print("Injected successfully into IndexScreenV2State.")
else:
    print("Could not find _MutedAdPlayer boundary.")

with open('c:/Users/savya/OneDrive/Documents/Samanyudu TV/Mobile_App/Samanyudu-News_App/lib/screens/index_v2.dart', 'w', encoding='utf-8') as f:
    f.write(content)
