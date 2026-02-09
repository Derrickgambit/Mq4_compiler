#property indicator_chart_window
#property indicator_buffers 2
#property indicator_color1 Lime
#property indicator_color2 Red
#property indicator_width1 2
#property indicator_width2 2

//================ INPUTS =================//
input bool   Enable_Gold        = true;

input bool   Use_H4_Bias        = true;
input bool   Use_H1_Bias        = true;

input bool   Use_M15_Entry      = true;
input bool   Use_M5_Entry       = true;

input bool   Use_FTR_Qualifier  = true;

input bool   Enable_Alerts     = true;
input bool   Enable_Push       = false;
input bool   Show_Arrows       = true;

input int    LookbackBars       = 300;
input int    MinImpulsePointsFX = 200;   // Forex
input int    MinImpulsePointsAU = 800;   // Gold

//================ BUFFERS =================//
double BuyArrow[];
double SellArrow[];

//================ INIT =================//
int OnInit()
{
   SetIndexBuffer(0, BuyArrow);
   SetIndexStyle(0, DRAW_ARROW);
   SetIndexArrow(0, 233);
   SetIndexEmptyValue(0, EMPTY_VALUE);

   SetIndexBuffer(1, SellArrow);
   SetIndexStyle(1, DRAW_ARROW);
   SetIndexArrow(1, 234);
   SetIndexEmptyValue(1, EMPTY_VALUE);

   IndicatorShortName("RTM Signal (H4+H1 Bias + FTR)");
   return(INIT_SUCCEEDED);
}

//================ MAIN =================//
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   if(rates_total < 50) return rates_total;

   int maxBars = MathMin(LookbackBars, rates_total - 2);

   for(int i = maxBars; i >= 1; i--)
   {
      BuyArrow[i]  = EMPTY_VALUE;
      SellArrow[i] = EMPTY_VALUE;

      if(!SymbolAllowed()) continue;

      int bias = GetBias();
      if(bias == 0) continue;

      bool engulfM15 = (Use_M15_Entry && IsEngulf(i, PERIOD_M15, bias));
      bool engulfM5  = (Use_M5_Entry  && IsEngulf(i, PERIOD_M5,  bias));

      if(!engulfM15 && !engulfM5) continue;

      bool ftrOk = true;
      if(Use_FTR_Qualifier)
         ftrOk = DetectFTR(bias);

      if(!ftrOk) continue;

      string tfTxt = engulfM5 ? "M5" : "M15";

      if(bias == 1 && Show_Arrows)
      {
         BuyArrow[i] = low[i] - (Point * 10);
         SendRTMAlert("BUY", tfTxt);
      }
      else if(bias == -1 && Show_Arrows)
      {
         SellArrow[i] = high[i] + (Point * 10);
         SendRTMAlert("SELL", tfTxt);
      }
   }
   return rates_total;
}

//================ SYMBOL FILTER =================//
bool SymbolAllowed()
{
   if(Symbol() == "XAUUSD" && Enable_Gold) return true;
   if(Symbol() != "XAUUSD") return true;
   return false;
}

//================ BIAS =================//
int GetBias()
{
   if(Use_H4_Bias && !TrendOK(PERIOD_H4)) return 0;
   if(Use_H1_Bias && !TrendOK(PERIOD_H1)) return 0;

   double c1 = iClose(Symbol(), PERIOD_H1, 1);
   double c2 = iClose(Symbol(), PERIOD_H1, 2);

   if(c1 > c2) return 1;
   if(c1 < c2) return -1;

   return 0;
}

//================ TREND STRUCTURE =================//
bool TrendOK(ENUM_TIMEFRAMES tf)
{
   double h1 = iHigh(Symbol(), tf, 1);
   double h2 = iHigh(Symbol(), tf, 2);
   double l1 = iLow(Symbol(), tf, 1);
   double l2 = iLow(Symbol(), tf, 2);

   if(h1 > h2 && l1 > l2) return true; // HH HL
   if(h1 < h2 && l1 < l2) return true; // LL LH

   return false;
}

//================ ENGULF =================//
bool IsEngulf(int shift, ENUM_TIMEFRAMES tf, int bias)
{
   double o1 = iOpen(Symbol(), tf, shift + 1);
   double c1 = iClose(Symbol(), tf, shift + 1);
   double o2 = iOpen(Symbol(), tf, shift);
   double c2 = iClose(Symbol(), tf, shift);

   double body1 = MathAbs(c1 - o1);
   double body2 = MathAbs(c2 - o2);

   if(body2 <= body1) return false;

   if(bias == 1 && c2 > o2 && c2 > o1 && o2 < c1) return true;
   if(bias == -1 && c2 < o2 && c2 < o1 && o2 > c1) return true;

   return false;
}

//================ FTR =================//
bool DetectFTR(int bias)
{
   ENUM_TIMEFRAMES tf1 = PERIOD_H1;
   ENUM_TIMEFRAMES tf2 = PERIOD_M15;

   int minPts = (Symbol() == "XAUUSD") ? MinImpulsePointsAU : MinImpulsePointsFX;

   if(ImpulseStrong(tf1, bias, minPts)) return true;
   if(ImpulseStrong(tf2, bias, minPts / 2)) return true;

   return false;
}

bool ImpulseStrong(ENUM_TIMEFRAMES tf, int bias, int minPts)
{
   double h = iHigh(Symbol(), tf, 1);
   double l = iLow(Symbol(), tf, 1);
   double range = MathAbs(h - l) / Point;

   if(range < minPts) return false;

   double c = iClose(Symbol(), tf, 1);
   double o = iOpen(Symbol(), tf, 1);

   if(bias == 1 && c > o) return true;
   if(bias == -1 && c < o) return true;

   return false;
}

//================ ALERT =================//
void SendRTMAlert(string side, string tf)
{
   static datetime lastBarTime = 0;
   datetime barTime = iTime(Symbol(), PERIOD_M1, 0);
   if(barTime == lastBarTime) return;
   lastBarTime = barTime;

   string msg = "RTM " + side +
                " | Engulf " + tf +
                " | " + Symbol();

   if(Enable_Alerts) Alert(msg);
   if(Enable_Push)   SendNotification(msg);
}
