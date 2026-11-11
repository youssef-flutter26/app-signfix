function extractLeadInfo(userMessage) {
  const text = String(userMessage || "").toLowerCase();
  const isSupportOrTracking = /order status|track|where is my|repair|fix|service ticket/i.test(text);
  if (isSupportOrTracking) return null;

  const buyingIntent = /quote|quotation|price|cost|buy|purchase|new sign|need a sign|want a sign|looking for|estimate|how much/i.test(text);
  if (!buyingIntent) return null;

  let product = null;
  if (/acrylic/i.test(text)) product = "Acrylic Letter Sign";
  else if (/led|glow/i.test(text)) product = "LED Board";
  else if (/neon/i.test(text)) product = "Neon Sign";
  else if (/flex/i.test(text)) product = "Flex Board";
  else if (/hoarding/i.test(text)) product = "Hoarding Signage";
  else product = "Custom Signage";

  const budgetMatch = text.match(/(?:budget|price|cost|around|approx|rs\.?|inr)\s*:?\s*(\d+[\d,]*)/i);
  const estimatedBudget = budgetMatch ? parseFloat(budgetMatch[1].replace(/,/g, "")) : null;

  return { requirement: userMessage, product, estimatedBudget, contact: null };
}

async function respond({ messages }) {
  const userMessage = [...(messages || [])].reverse().find((m) => m.role === "user")?.content || "";
  const lead = extractLeadInfo(userMessage);
  const text = userMessage.toLowerCase();

  let reply;

  // Human/support
  if (/human|support|agent|person|representative|helpdesk|contact|phone|call/i.test(text)) {
    reply = "I understand you would like to speak with our team. I have logged an escalation request and a SignFix representative will contact you shortly. You can also reach us directly through the Help & Support section in your profile.";

  // Pricing / quote
  } else if (/price|cost|rate|estimate|quote|quotation|how much|kitna|budget/i.test(text)) {
    reply = "SignFix pricing depends on sign size, material, and lighting type. For example:\n• LED Sign Board: ₹850/sq ft\n• Acrylic Letters: ₹650/sq ft\n• Flex Board: ₹280/sq ft\n\nPlease use the Order tab to get an instant estimate, or share your dimensions and I can help further!";

  // Order tracking
  } else if (/order|track|status|deliver|production|kahan|when|kab/i.test(text)) {
    reply = "You can track all your orders in the Track tab at the bottom of the screen. Tap on any order to see its current status, progress steps, and estimated delivery. For a specific order number, please share it here!";

  // Service / repair
  } else if (/service|repair|maintenance|warranty|fix|damaged|broken|band|kharab/i.test(text)) {
    reply = "SignFix offers complete sign board repair and maintenance services including:\n• LED module replacement\n• Acrylic panel repair\n• Electrical fault fixing\n• Routine maintenance\n\nGo to the Service tab to submit a request with photos and your location.";

  // Installation
  } else if (/install|fitting|mount|lagana|setup/i.test(text)) {
    reply = "Yes, SignFix provides professional installation services! When placing an order, simply toggle on 'Installation required' and our team will handle it. Installation charges start from ₹1,500 depending on size and location.";

  // Materials
  } else if (/material|acrylic|flex|acp|steel|alumin/i.test(text)) {
    reply = "SignFix uses premium materials:\n• Acrylic — premium indoor/outdoor signs\n• ACP (Aluminium Composite Panel) — durable outdoor boards\n• Flex — cost-effective printed boards\n• Stainless Steel — luxury lettering\n• PVC — lightweight indoor use\n\nWhich material are you interested in?";

  // Lighting
  } else if (/light|led|neon|backlit|glow|bright|chamak/i.test(text)) {
    reply = "We offer multiple lighting options:\n• LED — energy efficient, long lasting\n• Neon Flex — classic neon look\n• Backlit — soft glow from behind\n• Front Lit — bright face illumination\n• No Lighting — simple non-illuminated signs\n\nLED is our most popular choice for shops!";

  // Products / catalog
  } else if (/product|catalog|type|kind|sign board|kya/i.test(text)) {
    reply = "SignFix manufactures a wide range of sign boards:\n• LED Sign Boards\n• Acrylic 3D Letters\n• Flex/Banner Boards\n• Glow Sign Boards\n• Channel Letters\n• Neon Signs\n• Outdoor Hoardings\n• Nameplates\n\nTap the Order tab to place your order!";

  // Warranty
  } else if (/warranty|guarantee|kitne din|how long|duration/i.test(text)) {
    reply = "SignFix provides a 6-month warranty on all LED modules and a 1-year warranty on fabrication work. For warranty claims, simply raise a service request from the Service tab with photos of the issue.";

  // Delivery / time
  } else if (/delivery|time|days|kitne din|when ready|kab milega/i.test(text)) {
    reply = "Standard delivery time is 5-7 working days after order confirmation and quotation approval. Rush orders may be available — mention your deadline in the order notes and our team will try to accommodate!";

  // Payment
  } else if (/payment|pay|razorpay|upi|card|advance|paisa/i.test(text)) {
    reply = "SignFix accepts all major payment methods via Razorpay:\n• UPI (GPay, PhonePe, Paytm)\n• Credit/Debit Cards\n• Net Banking\n• EMI options available\n\nPayment is collected only after Admin approves your final quotation. No advance payment at order stage!";

  // Lead detected
  } else if (lead) {
    reply = `Thank you for your interest in ${lead.product}! I have noted your requirement. Our team will prepare a detailed quotation for you. To speed things up, please use the Order tab to submit your specifications (dimensions, material, location) and we will get back to you with the best price!`;

  // Greetings
  } else if (/hello|hi|hey|salaam|namaste|hlo|hii/i.test(text)) {
    reply = "Hello! Welcome to SignFix. I am your sign board assistant. I can help you with:\n• Product information & pricing\n• Order placement guidance\n• Service & repair support\n• Delivery & warranty queries\n\nWhat can I help you with today?";

  // Thanks
  } else if (/thank|thanks|shukriya|shukria/i.test(text)) {
    reply = "You are welcome! If you have any more questions about sign boards, orders, or services, feel free to ask. Happy to help!";

  // Default varied responses
  } else {
    const defaults = [
      "That's a great question! Could you please provide more details? I can help with sign board types, pricing, materials, orders, and services.",
      "I want to make sure I give you the right information. Are you looking for help with a new sign board order, a service request, or something else?",
      "I am here to help! Please tell me more about what you need — whether it's pricing, materials, installation, or tracking an existing order.",
      "SignFix offers complete sign board solutions from manufacturing to installation and maintenance. What specific information are you looking for?",
    ];
    reply = defaults[Math.floor(Math.random() * defaults.length)];
  }

  const requiresHuman = /human|support|agent|person|representative|dispute|emergency/i.test(text);

  return {
    reply,
    requiresHuman,
    lead,
    provider: "fallback-mock",
    providerResponseId: `mock-${Date.now()}`,
    usage: { total_tokens: 50 },
  };
}

module.exports = { respond };
