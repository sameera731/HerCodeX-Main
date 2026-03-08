import math

def computeSafetyScore(dPoliceKm, dNightlifeKm, hour):
    policeScore = math.exp(-0.28 * dPoliceKm)
    nightlifeRisk = math.exp(-0.45 * dNightlifeKm)

    isNight = (hour >= 20 or hour <= 5)

    if isNight:
        safety = 0.65 * policeScore - 0.35 * nightlifeRisk
    else:
        safety = 0.75 * policeScore - 0.25 * nightlifeRisk

    if safety < 0:
        return 0.0
    if safety > 1:
        return 1.0
    return safety