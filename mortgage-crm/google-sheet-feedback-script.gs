// Paste this into Extensions → Apps Script in the Google Sheet where you want feedback.
// Then: Deploy → New deployment → type "Web app" → Execute as: Me → Who has access: Anyone → Deploy.
// Copy the Web app URL and paste it into FEEDBACK_SHEET_URL at the top of index.html's script.

function doPost(e) {
  var data = JSON.parse(e.postData.contents);
  var book = SpreadsheetApp.getActiveSpreadsheet();
  var sheet = book.getSheetByName('Feedback') || book.insertSheet('Feedback');
  if (sheet.getLastRow() === 0) {
    sheet.appendRow(['Received', 'Name', 'Type', 'Feedback', 'Screen', 'Signed in as']);
  }
  sheet.appendRow([
    new Date(),
    String(data.name || '').slice(0, 80),
    String(data.type || '').slice(0, 20),
    String(data.text || '').slice(0, 3000),
    String(data.screen || '').slice(0, 60),
    String(data.persona || '').slice(0, 80)
  ]);
  return ContentService.createTextOutput('ok');
}
