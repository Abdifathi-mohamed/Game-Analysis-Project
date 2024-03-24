use game_analysis;

alter table player_details modify L1_Status varchar(30);
alter table player_details modify L2_Status varchar(30);
alter table player_details modify P_ID int primary key;
alter table player_details drop myunknowncolumn;

alter table level_details2 drop myunknowncolumn;
alter table level_details2 change timestamp start_datetime datetime;
alter table level_details2 modify Dev_Id varchar(10);
alter table level_details2 modify Difficulty varchar(15);
alter table level_details2 add primary key(P_ID, Dev_id, start_datetime);


-- Q1) Extract P_ID,Dev_ID,PName and Difficulty_level of all players 
-- at level 0

Select pd.P_ID, ld.Dev_ID, pd.PName, ld.Difficulty
from player_details pd 
join level_details2 ld on ld.P_ID = pd.P_ID
where Difficulty = 0;

-- Q2) Find Level1_code wise Avg_Kill_Count where lives_earned is 2 and atleast

SELECT pd.L1_code, AVG(ld.Kill_Count) AS Avg_Kill_Count
FROM player_details pd
JOIN level_details2 ld ON pd.P_ID = ld.P_ID
WHERE ld.Lives_Earned >= 2
GROUP BY pd.L1_code;

-- Q3) Find the total number of stages crossed at each diffuculty level
-- where for Level2 with players use zm_series devices. Arrange the result
-- in decsreasing order of total number of stages crossed.

select difficulty, SUM(Stages_Crossed) as Total_Stages_Crossed 
from level_details2
where Dev_ID like 'zm%'
GROUP BY Difficulty
ORDER BY Total_Stages_Crossed DESC;


-- Q4) Extract P_ID and the total number of unique dates for those players 
-- who have played games on multiple days.

SELECT P_ID, COUNT(DISTINCT start_datetime) as Total_Unique_Dates
from level_details2
group by  P_ID
HAVING COUNT(DISTINCT DATE(start_datetime)) > 1;


-- Q5) Find P_ID and level wise sum of kill_counts where kill_count
-- is greater than avg kill count for the Medium difficulty.

WITH AvgKillCount AS (
    SELECT level, AVG(kill_count) AS avg_kill_count
    FROM level_details2
    WHERE difficulty = 'Medium'
    GROUP BY level
)
SELECT ld.P_ID, ld.level, SUM(ld.kill_count) AS total_kill_count
FROM level_details2 ld
JOIN AvgKillCount akc ON ld.level = akc.level
WHERE ld.kill_count > akc.avg_kill_count
GROUP BY ld.P_ID, ld.level;

-- Q6)  Find Level and its corresponding Level code wise sum of lives earned 
-- excluding level 0. Arrange in asecending order of level.

SELECT ld.Level, pd.L1_code AS Level_Code, SUM(ld.Lives_Earned) AS Total_Lives_Earned
FROM level_details2 ld
JOIN player_details pd ON ld.P_ID = pd.P_ID
WHERE ld.level <> 0
GROUP BY ld.level, pd.L1_code
ORDER BY ld.level ASC;

-- Q7) Find Top 3 score based on each dev_id and Rank them in increasing order
-- using Row_Number. Display difficulty as well.

WITH RankedScores AS (
    SELECT Dev_ID, difficulty, score,
           ROW_NUMBER() OVER (PARTITION BY Dev_ID ORDER BY score DESC) AS rn
    FROM level_details2
)
SELECT Dev_ID, difficulty, score
FROM RankedScores
WHERE rn <= 3;

-- Q8) Find first_login datetime for each device id

SELECT Dev_ID, MIN(start_datetime) AS First_Login
FROM level_details2
GROUP BY Dev_ID;


 -- Q9) Find Top 5 score based on each difficulty level and Rank them in 
-- increasing order using Rank. Display dev_id as well.

WITH RankedScores AS (
    SELECT Dev_ID, difficulty, score,
           RANK() OVER (PARTITION BY difficulty ORDER BY score DESC) AS rnk
    FROM level_details2
)
SELECT Dev_ID, difficulty, score, rnk
FROM RankedScores
WHERE rnk <= 5;

-- Q10) Find the device ID that is first logged in(based on start_datetime) 
-- for each player(p_id). Output should contain player id, device id and 
-- first login datetime.

WITH FirstLogin AS (
    SELECT P_ID, MIN(date(start_datetime)) AS first_login
    FROM level_details2
    GROUP BY P_ID
)
SELECT ld.P_ID, ld.Dev_ID, fl.first_login
FROM FirstLogin fl
JOIN level_details2 ld ON fl.P_ID = ld.P_ID AND fl.first_login = date(ld.start_datetime);



-- Q11) For each player and date, how many kill_count played so far by the player. That is, the total number of games played 
-- by the player until that date.
-- a) window function

SELECT P_ID, DATE(start_datetime) AS Date, 
       SUM(kill_count) OVER (PARTITION BY P_ID ORDER BY DATE(start_datetime)) AS Total_Kill_Count
FROM level_details2;

-- b) without window function
SELECT ld.P_ID, DATE(ld.start_datetime) AS Date,
       SUM(ld1.kill_count) AS Total_Kill_Count
FROM level_details2 ld
JOIN level_details2 ld1 ON ld.P_ID = ld1.P_ID AND ld.start_datetime >= ld1.start_datetime
GROUP BY ld.P_ID, DATE(ld.start_datetime);

-- Q12) Find the cumulative sum of stages crossed over a start_datetime 

WITH CumulativeStages AS (
    SELECT P_ID, start_datetime, stages_crossed,
           SUM(stages_crossed) OVER (PARTITION BY P_ID ORDER BY start_datetime ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS Cumulative_Stages
    FROM level_details2
)
SELECT P_ID, start_datetime, stages_crossed, Cumulative_Stages
FROM CumulativeStages;

-- Q13) Find the cumulative sum of an stages crossed over a start_datetime 
-- for each player id but exclude the most recent start_datetime

WITH RankedStages AS (
    SELECT P_ID, start_datetime, stages_crossed,
           ROW_NUMBER() OVER (PARTITION BY P_ID ORDER BY start_datetime DESC) AS rn
    FROM level_details2
)
SELECT rs.P_ID, rs.start_datetime, rs.stages_crossed,
       SUM(rs.stages_crossed) OVER (PARTITION BY rs.P_ID ORDER BY rs.start_datetime ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS Cumulative_Stages
FROM RankedStages rs
WHERE rs.rn > 1;

-- Q14) Extract top 3 highest sum of score for each device id and the corresponding player_id

WITH RankedScores AS (
    SELECT P_ID, Dev_ID, SUM(Score) AS Total_Score,
           ROW_NUMBER() OVER (PARTITION BY Dev_ID ORDER BY SUM(score) DESC) AS rn
    FROM level_details2
    GROUP BY P_ID, Dev_ID
)
SELECT P_ID, Dev_ID, Total_Score
FROM RankedScores
WHERE rn <= 3;

-- Q15) Find players who scored more than 50% of the avg score scored by sum of scores for each player_id

WITH PlayerScores AS (
    SELECT P_ID, SUM(Score) AS Total_Score
    FROM level_details2
    GROUP BY P_ID
),
AverageScores AS (
    SELECT AVG(Total_Score) AS Avg_Score
    FROM PlayerScores
)
SELECT ps.P_ID, ps.Total_Score
FROM PlayerScores ps
JOIN AverageScores avg ON ps.Total_Score > 0.5 * avg.Avg_Score;


-- Q16) Create a stored procedure to find top n headshots_count based on each dev_id and Rank them in increasing order using Row_Number. Display difficulty as well.

DELIMITER $$
CREATE PROCEDURE GetTopNHeadshots(IN n INT)
BEGIN
    WITH RankedHeadshots AS (
        SELECT
            Dev_ID,
            difficulty,
            headshots_count,
            ROW_NUMBER() OVER (PARTITION BY Dev_ID ORDER BY headshots_count ASC) AS rn
        FROM
            level_details2
    )
    SELECT
        Dev_ID,
        difficulty,
        headshots_count
    FROM
        RankedHeadshots
    WHERE
        rn <= n;
END$$
DELIMITER ;

CALL GetTopNHeadshots(3);


-- Q17) Create a function to return sum of Score for a given player_id.

DELIMITER $$

CREATE FUNCTION GetTotalScoreForPlayer(P_ID INT)
RETURNS INT
DETERMINISTIC
BEGIN
    DECLARE TotalScore INT;
    
    SELECT SUM(score) INTO TotalScore
    FROM level_details
    WHERE P_ID = P_ID;
    
    RETURN COALESCE(TotalScore, 0);
END$$

DELIMITER ;
