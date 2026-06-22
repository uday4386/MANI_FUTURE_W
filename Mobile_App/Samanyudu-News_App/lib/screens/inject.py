import sys

with open('c:/Users/savya/OneDrive/Documents/Samanyudu TV/Mobile_App/Samanyudu-News_App/lib/screens/index_v2.dart', 'r', encoding='utf-8') as f:
    target = f.read()

with open('c:/Users/savya/OneDrive/Documents/Samanyudu TV/Mobile_App/Samanyudu-News_App/lib/screens/v2_ui_chunk.dart', 'r', encoding='utf-8') as f:
    chunk = f.read()

old_sig = "Widget build(BuildContext context) {"
new_sig = "Widget build(BuildContext context) {\n    return _buildNewUI(context);\n  }\n\n  Widget _oldBuild(BuildContext context) {"
if old_sig in target:
    target = target.replace(old_sig, new_sig, 1)
    print("Replaced build signature.")
else:
    print("Could not find build signature.")

parts = target.rsplit('}', 1)
target = parts[0] + chunk + '\n}\n'

with open('c:/Users/savya/OneDrive/Documents/Samanyudu TV/Mobile_App/Samanyudu-News_App/lib/screens/index_v2.dart', 'w', encoding='utf-8') as f:
    f.write(target)
print("Injection complete.")
