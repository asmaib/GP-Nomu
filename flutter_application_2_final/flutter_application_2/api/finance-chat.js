// api/finance-chat.js
import { Configuration, OpenAIApi } from "openai";

const openai = new OpenAIApi(
  new Configuration({ apiKey: process.env.OPENAI_API_KEY })
);

export default async function handler(req, res) {
  if (req.method !== "POST") {
    return res.status(405).json({ error: "Only POST allowed" });
  }
  const { text } = req.body;
  if (!text) return res.status(400).json({ error: "No text provided" });

  const systemPrompt = `
You are Nomu’s expert trading and finance guide.
Answer user questions clearly and concisely with practical advice.
`;
  try {
    const aiRes = await openai.createChatCompletion({
      model: "gpt-3.5-turbo",
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: text }
      ]
    });
    const reply = aiRes.data.choices[0].message.content;
    res.status(200).json({ reply });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "OpenAI request failed" });
  }
}
