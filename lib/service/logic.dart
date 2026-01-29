import 'dart:math';

class PropertyCalculator {
  // --- UTILITIES ---
  static double calculateEMI(
    double principal,
    double annualRate,
    double years,
  ) {
    if (principal <= 0 || years <= 0) return 0;
    if (annualRate <= 0) return principal / (years * 12);
    double monthlyRate = annualRate / (12 * 100);
    double months = years * 12;
    return principal *
        monthlyRate *
        pow(1 + monthlyRate, months) /
        (pow(1 + monthlyRate, months) - 1);
  }

  static double calculateOutstanding(
    double principal,
    double annualRate,
    double years,
    double paymentsMade,
  ) {
    if (principal <= 0 || paymentsMade <= 0) return principal;
    double monthlyRate = annualRate / (12 * 100);
    double totalMonths = years * 12;
    if (paymentsMade >= totalMonths) return 0;
    return max(
      0,
      principal *
          (pow(1 + monthlyRate, totalMonths) -
              pow(1 + monthlyRate, paymentsMade)) /
          (pow(1 + monthlyRate, totalMonths) - 1),
    );
  }

  static double calculateTotalInterest(
    double principal,
    double annualRate,
    double years,
    double paymentsMade,
  ) {
    if (principal <= 0 || paymentsMade <= 0) return 0;
    double monthlyRate = annualRate / (12 * 100);
    double emi = calculateEMI(principal, annualRate, years);
    double interestPaid = 0;
    double remainingPrincipal = principal;

    for (int i = 0; i < paymentsMade; i++) {
      if (remainingPrincipal <= 0) break;
      double interestForMonth = remainingPrincipal * monthlyRate;
      double principalForMonth = emi - interestForMonth;
      interestPaid += interestForMonth;
      remainingPrincipal -= principalForMonth;
    }
    return interestPaid;
  }

  static double getSafeValue(dynamic val) {
    return double.tryParse(val.toString()) ?? 0;
  }

  // --- MAIN CALCULATION ---
  static Map<String, dynamic> calculate(
    Map<String, dynamic> data,
    Map<String, dynamic> selections,
  ) {
    // 1. Extract Inputs
    double size = getSafeValue(selections['selectedPropertySize']);
    double purchasePrice = getSafeValue(data['purchasePrice']);
    double otherCharges = getSafeValue(data['otherCharges']);
    double stampDutyPct = getSafeValue(data['stampDuty']);
    double gstPct = getSafeValue(data['gstPercentage']);
    String paymentPlan = data['paymentPlan'] ?? 'clp';
    var assumptions = data['assumptions'];

    // Holding Period
    double yearsInput = getSafeValue(assumptions['investmentPeriod']);
    String unit = assumptions['holdingPeriodUnit'] ?? 'years';
    double totalHoldingMonths = unit == 'months' ? yearsInput : yearsInput * 12;

    double baseCost = size * purchasePrice;
    double agreementValue = baseCost + otherCharges;
    double stampDutyCost = agreementValue * (stampDutyPct / 100);
    double gstCost = agreementValue * (gstPct / 100);
    double totalCost = baseCost;

    // Loan Shares
    double hlShare = 80;
    double pl1Share = 10;
    double pl2Share = 10;
    double dpShare = 0;

    if (paymentPlan == 'clp') {
      hlShare = 80;
      pl1Share = 10;
      pl2Share = 10;
      dpShare = 0;
    } else if (paymentPlan == '80-20') {
      hlShare = 80;
      pl1Share = 20;
      pl2Share = 0;
      dpShare = 0;
    } else if (paymentPlan == '25-75') {
      hlShare = 75;
      pl1Share = 25;
      pl2Share = 0;
      dpShare = 0;
    } else if (paymentPlan == 'rtm') {
      hlShare = 80;
      pl1Share = 20;
      pl2Share = 0;
      dpShare = 0;
    } else {
      hlShare = getSafeValue(assumptions['homeLoanShare']);
      pl1Share = getSafeValue(assumptions['personalLoan1Share']);
      pl2Share = getSafeValue(assumptions['personalLoan2Share']);
      dpShare = getSafeValue(assumptions['downPaymentShare']);
    }

    double hlAmount = totalCost * (hlShare / 100);
    double pl1Amount = totalCost * (pl1Share / 100);
    double pl2Amount = totalCost * (pl2Share / 100);
    double dpAmount = totalCost * (dpShare / 100);
    double totalCashInvested = dpAmount + pl1Amount + pl2Amount;

    // Rates & Tenures
    double hlRate = getSafeValue(assumptions['homeLoanRate']);
    double hlTerm = getSafeValue(assumptions['homeLoanTerm']);
    double pl1Rate = getSafeValue(assumptions['personalLoan1Rate']);
    double pl1Term = getSafeValue(assumptions['personalLoan1Term']);
    double pl2Rate = getSafeValue(assumptions['personalLoan2Rate']);
    double pl2Term = getSafeValue(assumptions['personalLoan2Term']);

    double hlEMI = calculateEMI(hlAmount, hlRate, hlTerm);
    double pl1EMI = calculateEMI(pl1Amount, pl1Rate, pl1Term);
    double pl2EMI = calculateEMI(pl2Amount, pl2Rate, pl2Term);

    // --- TIMING LOGIC ---
    List props = data['properties'] as List;
    var matchingProps = props.where(
      (p) => p['id'] == selections['selectedPropertyId'],
    );
    var activeProp = matchingProps.isNotEmpty
        ? matchingProps.first
        : (props.isNotEmpty ? props[0] : {});
    double possessionMonths = getSafeValue(
      activeProp['possessionMonths'] ?? 24,
    );

    double lastDemandMonth = possessionMonths;
    if (paymentPlan == 'clp') {
      double explicitLast = getSafeValue(
        assumptions['lastBankDisbursementMonth'],
      );
      double constructionEnd =
          getSafeValue(assumptions['clpDurationYears']) * 12;
      lastDemandMonth = explicitLast > 0
          ? explicitLast
          : (constructionEnd > 0 ? constructionEnd : possessionMonths);
    }

    double hlInputDelay = getSafeValue(assumptions['homeLoanStartMonth']);
    double realHomeLoanStartMonth;
    if (assumptions['homeLoanStartMode'] == 'manual') {
      realHomeLoanStartMonth = hlInputDelay;
    } else {
      realHomeLoanStartMonth = lastDemandMonth + hlInputDelay + 1;
    }

    double pl1StartMonth = getSafeValue(assumptions['personalLoan1StartMonth']);
    double pl2Delay = getSafeValue(assumptions['personalLoan2StartMonth']);
    double pl2StartMonth = possessionMonths + pl2Delay + 1;

    // --- SIMULATION LOOP ---
    double interestCutoffMonth = possessionMonths;

    // 1. If Last Disbursement is set, that is the natural cutoff
    double explicitLast = getSafeValue(
      assumptions['lastBankDisbursementMonth'],
    );
    if (explicitLast > 0) {
      interestCutoffMonth = explicitLast;
    }

    // 2. If Manual Mode is ON, interest stops 1 month before EMI starts
    if (assumptions['homeLoanStartMode'] == 'manual') {
      double manualMonth = getSafeValue(assumptions['homeLoanStartMonth']);
      if (manualMonth > 0) {
        interestCutoffMonth = manualMonth - 1;
      }
    }
    double cumulativeDisbursement = 0;
    List<Map<String, dynamic>> monthlyLedger = [];
    double totalIDC = 0;
    double minIDCEMI = 0;
    double maxIDCEMI = 0;
    bool isFirstIDCPayment = false;
    double runningPrePossessionTotal = 0;
    double runningPostPossessionTotal = 0;

    List<Map<String, dynamic>> idcSchedule = [];
    double interval = getSafeValue(assumptions['bankDisbursementInterval']);
    if (interval == 0) interval = 3;
    double startMonth = getSafeValue(assumptions['bankDisbursementStartMonth']);
    if (startMonth == 0) startMonth = 1;

    double fundingEndMonth = lastDemandMonth;
    int slabsCount = ((fundingEndMonth - startMonth) / interval).floor() + 1;
    if (slabsCount < 1) slabsCount = 1;
    double slabAmount = hlAmount > 0 ? hlAmount / slabsCount : 0;

    for (int i = 0; i < slabsCount; i++) {
      double m = startMonth + (i * interval);
      if (m <= fundingEndMonth && hlAmount > 0) {
        double monthlyInt = (slabAmount * (hlRate / 100)) / 12;
        double duration = max(0, interestCutoffMonth - m);
        idcSchedule.add({
          'slabNo': i + 1,
          'releaseMonth': m,
          'amount': slabAmount,
          'interestCost': monthlyInt * duration,
        });
      }
    }

    for (int m = 1; m <= totalHoldingMonths; m++) {
      double monthlyHLOutflow = 0;
      bool isPrePossession = m <= possessionMonths;

      if (paymentPlan == 'clp' && hlAmount > 0 && m < realHomeLoanStartMonth) {
        bool isScheduleMonth =
            (m >= startMonth) && ((m - startMonth) % interval == 0);
        if (m <= fundingEndMonth) {
          if (m == startMonth || (isScheduleMonth && m != startMonth)) {
            if (cumulativeDisbursement < (hlAmount - 10)) {
              cumulativeDisbursement += slabAmount;
              if (cumulativeDisbursement > hlAmount)
                cumulativeDisbursement = hlAmount;
            }
          }
        }
        double monthlyInterest = (cumulativeDisbursement * (hlRate / 100)) / 12;
        monthlyHLOutflow = monthlyInterest;
        totalIDC += monthlyInterest;

        if (monthlyInterest > 0) {
          if (!isFirstIDCPayment) {
            minIDCEMI = monthlyInterest;
            isFirstIDCPayment = true;
          }
          maxIDCEMI = monthlyInterest;
        }
      } else {
        if (m >= realHomeLoanStartMonth) monthlyHLOutflow = hlEMI;
      }

      double monthlyPL1 = (pl1Amount > 0 && m >= pl1StartMonth) ? pl1EMI : 0;
      double monthlyPL2 = (pl2Amount > 0 && m >= pl2StartMonth) ? pl2EMI : 0;
      double totalMonthOutflow = monthlyHLOutflow + monthlyPL1 + monthlyPL2;

      if (isPrePossession) {
        runningPrePossessionTotal += totalMonthOutflow;
      } else {
        runningPostPossessionTotal += totalMonthOutflow;
      }
      // ... existing accumulation logic (runningPrePossessionTotal += ...) ...

      // ✅ ADD THIS: Save the calculated values for this specific month
      monthlyLedger.add({
        'month': m,
        'cumulativeLoan':
            cumulativeDisbursement, // Shows the loan growing (Blue text in your image)
        'hlComponent':
            monthlyHLOutflow, // This is the missing IDC Interest! (₹1,500, ₹3,000 etc.)
        'pl1Component': monthlyPL1, // PL1 EMI
        'pl2Component': monthlyPL2, // PL2 EMI
        'totalOutflow': totalMonthOutflow, // The sum (IDC + PL1)
        // Helper flags for UI styling
        'isPrePossession': isPrePossession,
        'slabActive': (paymentPlan == 'clp' && m <= fundingEndMonth)
            ? ((m - startMonth) ~/ interval) + 1
            : 0,
      });
    }

    double monthlyIDCEMI = (totalIDC > 0 && possessionMonths > 0)
        ? totalIDC / possessionMonths
        : 0;

    double hlPaymentsMade = max(
      0,
      totalHoldingMonths - (realHomeLoanStartMonth - 1),
    );
    double pl1PaymentsMade = max(0, totalHoldingMonths - pl1StartMonth);
    double pl2PaymentsMade = max(0, totalHoldingMonths - pl2StartMonth);

    double hlOutstanding = calculateOutstanding(
      hlAmount,
      hlRate,
      hlTerm,
      hlPaymentsMade,
    );
    double pl1Outstanding = calculateOutstanding(
      pl1Amount,
      pl1Rate,
      pl1Term,
      pl1PaymentsMade,
    );
    double pl2Outstanding = calculateOutstanding(
      pl2Amount,
      pl2Rate,
      pl2Term,
      pl2PaymentsMade,
    );
    double totalOutstanding = hlOutstanding + pl1Outstanding + pl2Outstanding;

    double hlInterestPaid = calculateTotalInterest(
      hlAmount,
      hlRate,
      hlTerm,
      hlPaymentsMade,
    );
    double pl1InterestPaid = calculateTotalInterest(
      pl1Amount,
      pl1Rate,
      pl1Term,
      pl1PaymentsMade,
    );
    double pl2InterestPaid = calculateTotalInterest(
      pl2Amount,
      pl2Rate,
      pl2Term,
      pl2PaymentsMade,
    );

    double trueTotalInterest =
        (paymentPlan == 'clp' ? totalIDC : 0) +
        hlInterestPaid +
        pl1InterestPaid +
        pl2InterestPaid;
    double totalEMIPaid =
        runningPrePossessionTotal + runningPostPossessionTotal;

    // --- ROI CALCULATION FIX ---
    // ✅ FIX 1: Denominator must be (Down Payment + Total EMIs), NOT (Total Cash Invested + Total EMIs)
    // React Logic: const totalActualInvestment = downPaymentAmount + totalEMIPaid;
    double totalActualInvestment = dpAmount + totalEMIPaid;

    // Base Result
    double baseExitPrice = getSafeValue(selections['selectedExitPrice']);
    double saleValue = size * baseExitPrice;
    double leftoverCash = saleValue - totalOutstanding;
    double netProfit = leftoverCash - totalEMIPaid - dpAmount;

    // ✅ FIX 2: Use the corrected denominator for ROI
    double roi = totalActualInvestment > 0
        ? (netProfit / totalActualInvestment) * 100
        : 0;

    // Scenarios
    Set<double> pricesToSimulate = {baseExitPrice};
    if (selections['scenarioExitPrices'] != null) {
      for (var p in selections['scenarioExitPrices']) {
        pricesToSimulate.add(getSafeValue(p));
      }
    }
    List<double> sortedPrices = pricesToSimulate.where((p) => p > 0).toList()
      ..sort();

    List<Map<String, dynamic>> scenarios = [];
    for (double price in sortedPrices) {
      double sSaleValue = size * price;
      double sLeftover = sSaleValue - totalOutstanding;
      double sNetProfit = sLeftover - totalEMIPaid - dpAmount;
      double sRoi = totalActualInvestment > 0
          ? (sNetProfit / totalActualInvestment) * 100
          : 0;

      scenarios.add({
        'exitPrice': price,
        'saleValue': sSaleValue,
        'leftoverCash': sLeftover,
        'netProfit': sNetProfit,
        'roi': sRoi,
        'isSelected': price == baseExitPrice,
      });
    }

    // --- 4. SMART SAVER STRATEGY COMPARISON (CLP Only) ---
    Map<String, dynamic>? strategyComparison;

    if (paymentPlan == 'clp' && hlAmount > 0) {
      double localInterval = interval;
      double localSlabAmount = slabAmount;

      // ✅ FIX 3: Updated Loop Logic to Match React Exactly (Linear Slabs, Modulo Interval)
      // Simulation A: Standard CLP
      double stdTotalPaid = 0;
      double stdCumulativeDisb = 0;

      for (int m = 1; m <= possessionMonths.toInt(); m++) {
        // React Logic: if (m % interval === 0 && cumDisb < hlAmount)
        if (m % localInterval == 0 && stdCumulativeDisb < hlAmount) {
          stdCumulativeDisb += localSlabAmount;
          if (stdCumulativeDisb > hlAmount) stdCumulativeDisb = hlAmount;
        }
        stdTotalPaid += (stdCumulativeDisb * (hlRate / 100)) / 12;
      }

      double standardBalanceAtPossession = hlAmount;

      // Simulation B: Smart Saver
      double smartTotalPaid = 0;
      double smartBalance = 0;
      double smartPrincipalPaid = 0;
      double smartCumulativeDisb = 0;

      for (int m = 1; m <= possessionMonths.toInt(); m++) {
        // 1. Disbursement Logic (Same as Standard)
        if (m % localInterval == 0 && smartCumulativeDisb < hlAmount) {
          smartCumulativeDisb += localSlabAmount;
          smartBalance += localSlabAmount;
          if (smartCumulativeDisb > hlAmount) smartCumulativeDisb = hlAmount;
        }

        // 2. Payment Logic (Full EMI)
        double monthlyInt = (smartBalance * (hlRate / 100)) / 12;
        double principalComp = hlEMI - monthlyInt;

        smartBalance -= principalComp;
        smartPrincipalPaid += principalComp;
        smartTotalPaid += hlEMI;
      }

      strategyComparison = {
        'stdTotal': stdTotalPaid,
        'stdBalance': standardBalanceAtPossession,
        'smartTotal': smartTotalPaid,
        'smartBalance': hlAmount - smartPrincipalPaid,
        'savings': smartPrincipalPaid,
      };
    }

    return {
      'homeLoanStartMode': assumptions['homeLoanStartMode'],
      'homeLoanStartMonth': assumptions['homeLoanStartMonth'],
      'propertySize': size,
      'purchasePrice': purchasePrice,
      'totalCost': totalCost,
      'gstCost': gstCost,
      'stampDutyCost': stampDutyCost,
      'homeLoanAmount': hlAmount,
      'homeLoanShare': hlShare,
      'downPaymentAmount': dpAmount,
      'downPaymentShare': dpShare,
      'personalLoan1Amount': pl1Amount,
      'personalLoan1Share': pl1Share,
      'personalLoan2Amount': pl2Amount,
      'personalLoan2Share': pl2Share,
      'strategyComparison': strategyComparison,
      'totalCashInvested': totalCashInvested,

      'homeLoanEMI': hlEMI,
      'personalLoan1EMI': pl1EMI,
      'personalLoan2EMI': pl2EMI,

      'monthlyIDCEMI': monthlyIDCEMI,
      'minIDCEMI': minIDCEMI,
      'maxIDCEMI': maxIDCEMI,
      'totalIDC': totalIDC,
      'idcSchedule': idcSchedule,

      'totalEMIPaid': totalEMIPaid,
      'totalInterestPaid': trueTotalInterest,
      'homeLoanInterestPaid': hlInterestPaid,

      'saleValue': saleValue,
      'totalLoanOutstanding': totalOutstanding,
      'homeLoanOutstanding': hlOutstanding,
      'personalLoan1Outstanding': pl1Outstanding,
      'personalLoan2Outstanding': pl2Outstanding,

      'leftoverCash': leftoverCash,
      'netGainLoss': netProfit,
      'roi': roi,

      'years': (totalHoldingMonths / 12),
      'monthlyLedger': monthlyLedger,
      'possessionMonths': possessionMonths,
      'totalHoldingMonths': totalHoldingMonths,
      'constructionMonths': lastDemandMonth,

      'prePossessionTotal': runningPrePossessionTotal,
      'postPossessionTotal': runningPostPossessionTotal,
      'postPossessionEMI': hlEMI + pl1EMI + pl2EMI,
      'prePossessionMonths': min(totalHoldingMonths, possessionMonths),
      'postPossessionMonths': max(0, totalHoldingMonths - possessionMonths),

      'pl1StartMonth': pl1StartMonth,
      'pl2StartMonth': pl2StartMonth,

      'hasHomeLoan': hlAmount > 0,
      'hasPersonalLoan1': pl1Amount > 0,
      'hasPersonalLoan2': pl2Amount > 0,
      'hasIDC': totalIDC > 0,

      'exitPrice': baseExitPrice,
      'multipleScenarios': scenarios,
    };
  }
}
