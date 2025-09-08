# script.py


import subprocess

def main():
    cmd = [
        r".\node_modules\.bin\npx.cmd",
        "hardhat", "ignition", "deploy",
        "ignition/modules/RainyDayFund.ts",
        "--network", "sepolia"
    ]

    process = subprocess.run(cmd)

    if process.returncode == 0:
        print("\n✅ Deployment finished successfully")
    else:
        print("\n❌ Deployment failed")

if __name__ == "__main__":
    main()

