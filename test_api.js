fetch("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key=AIzaSyA1S0QLDlQMn3qKfa48iL1p2WZsUI8yMM4", {
  method: "POST",
  headers: {
    "Content-Type": "application/json"
  },
  body: JSON.stringify({
    contents: [{
      parts: [{
        text: "A cute cat"
      }]
    }]
  })
})
.then(r => r.json())
.then(console.log)
.catch(console.error);
